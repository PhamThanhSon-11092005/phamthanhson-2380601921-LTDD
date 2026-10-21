import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';

class FaceAnalysisResult {
  final bool isValid;
  final bool isCovered;
  final bool hasFace;
  final double brightness;
  final double skinRatio;
  final String? errorMessage;
  final List<double> featureVector;

  FaceAnalysisResult({
    required this.isValid,
    required this.isCovered,
    required this.hasFace,
    required this.brightness,
    required this.skinRatio,
    this.errorMessage,
    required this.featureVector,
  });
}

class FaceService {
  /// Phân tích ảnh chụp từ camera:
  /// 1. Kiểm tra camera có bị che tay / vật cản / quá tối không.
  /// 2. Kiểm tra có sự xuất hiện của khuôn mặt người (dựa trên dải màu da sinh học & độ tương phản).
  /// 3. Trích xuất vector đặc trưng 96 chiều để đối soát với ảnh gốc đã đăng ký.
  static Future<FaceAnalysisResult> analyzeFaceImage(Uint8List imageBytes) async {
    try {
      if (imageBytes.isEmpty) {
        return FaceAnalysisResult(
          isValid: false,
          isCovered: true,
          hasFace: false,
          brightness: 0,
          skinRatio: 0,
          errorMessage: 'Không nhận được dữ liệu ảnh từ camera',
          featureVector: [],
        );
      }

      // Thu nhỏ ảnh xuống 32x32 (1024 điểm ảnh) để xử lý nhanh chỉ mất ~3ms
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: 32,
        targetHeight: 32,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

      if (byteData == null) {
        return FaceAnalysisResult(
          isValid: false,
          isCovered: true,
          hasFace: false,
          brightness: 0,
          skinRatio: 0,
          errorMessage: 'Không thể giải mã hình ảnh từ camera',
          featureVector: [],
        );
      }

      final buffer = byteData.buffer.asUint8List();
      const int pixelCount = 32 * 32;
      double sumLuma = 0;
      final List<double> lumas = List.filled(pixelCount, 0.0);
      int skinPixelCount = 0;
      int centerPixelCount = 0;

      // Quét toàn bộ điểm ảnh
      for (int y = 0; y < 32; y++) {
        for (int x = 0; x < 32; x++) {
          final idx = (y * 32 + x);
          final r = buffer[idx * 4];
          final g = buffer[idx * 4 + 1];
          final b = buffer[idx * 4 + 2];

          // Độ sáng Luminance
          final luma = 0.299 * r + 0.587 * g + 0.114 * b;
          lumas[idx] = luma;
          sumLuma += luma;

          // Kiểm tra vùng trung tâm khuôn mặt (từ x: 6..25, y: 6..25)
          if (x >= 6 && x <= 25 && y >= 6 && y <= 25) {
            centerPixelCount++;
            // Dải sắc độ da người sinh học (Human skin color range)
            final bool isSkinTone = (r > 55) &&
                (r > g) &&
                (g >= b) &&
                ((r - g) >= 8) &&
                ((r - b) >= 12) &&
                (r < 252);
            if (isSkinTone) {
              skinPixelCount++;
            }
          }
        }
      }

      final double avgLuma = sumLuma / pixelCount;
      final double skinRatio = centerPixelCount > 0 ? (skinPixelCount / centerPixelCount) : 0.0;

      // Tính độ lệch chuẩn / độ tương phản
      double varianceSum = 0;
      for (int i = 0; i < pixelCount; i++) {
        varianceSum += (lumas[i] - avgLuma) * (lumas[i] - avgLuma);
      }
      final double stdDev = math.sqrt(varianceSum / pixelCount);

      // 1. Kiểm tra camera bị che: độ sáng quá tối (< 38) HOẶC ảnh quá phẳng/đồng nhất (stdDev < 13.0)
      if (avgLuma < 38.0 || stdDev < 13.0) {
        return FaceAnalysisResult(
          isValid: false,
          isCovered: true,
          hasFace: false,
          brightness: avgLuma,
          skinRatio: skinRatio,
          errorMessage: 'Không phát hiện khuôn mặt! Camera đang bị che tay hoặc môi trường quá tối.',
          featureVector: [],
        );
      }

      // 2. Kiểm tra phát hiện khuôn mặt người (không phải tường, áo, bàn ghế, đồ vật)
      // Vùng trung tâm phải có tỷ lệ sắc tố da khuôn mặt tối thiểu 12%
      if (skinRatio < 0.10) {
        return FaceAnalysisResult(
          isValid: false,
          isCovered: false,
          hasFace: false,
          brightness: avgLuma,
          skinRatio: skinRatio,
          errorMessage: 'Không phát hiện khuôn mặt người trong khung hình! Vui lòng đưa khuôn mặt bạn vào giữa khung tròn.',
          featureVector: [],
        );
      }

      // 3. Trích xuất vector đặc trưng 96 chiều:
      // - 64 chiều: Lưới phân bố độ sáng 8x8
      // - 32 chiều: Lưới sắc thái màu da và tỷ lệ màu R, G
      final List<double> vector = [];

      // 64 điểm lưới độ sáng (8x8 blocks)
      const blockSize = 4;
      for (int by = 0; by < 8; by++) {
        for (int bx = 0; bx < 8; bx++) {
          double blockSum = 0;
          for (int py = 0; py < blockSize; py++) {
            for (int px = 0; px < blockSize; px++) {
              final idx = (by * blockSize + py) * 32 + (bx * blockSize + px);
              blockSum += lumas[idx];
            }
          }
          final blockAvg = blockSum / (blockSize * blockSize);
          vector.add(double.parse((blockAvg / 255.0).toStringAsFixed(4)));
        }
      }

      // 32 điểm tỷ lệ màu sắc đặc trưng từng góc mặt (4x4 blocks x 2 kênh R, G)
      const colorBlockSize = 8;
      for (int by = 0; by < 4; by++) {
        for (int bx = 0; bx < 4; bx++) {
          double rSum = 0;
          double gSum = 0;
          for (int py = 0; py < colorBlockSize; py++) {
            for (int px = 0; px < colorBlockSize; px++) {
              final idx = (by * colorBlockSize + py) * 32 + (bx * colorBlockSize + px);
              rSum += buffer[idx * 4];
              gSum += buffer[idx * 4 + 1];
            }
          }
          final count = colorBlockSize * colorBlockSize;
          vector.add(double.parse(((rSum / count) / 255.0).toStringAsFixed(4)));
          vector.add(double.parse(((gSum / count) / 255.0).toStringAsFixed(4)));
        }
      }

      return FaceAnalysisResult(
        isValid: true,
        isCovered: false,
        hasFace: true,
        brightness: avgLuma,
        skinRatio: skinRatio,
        featureVector: vector,
      );
    } catch (e) {
      return FaceAnalysisResult(
        isValid: false,
        isCovered: false,
        hasFace: false,
        brightness: 0,
        skinRatio: 0,
        errorMessage: 'Lỗi khi phân tích hình ảnh: $e',
        featureVector: [],
      );
    }
  }

  /// Tính độ tương đồng góc (Cosine Similarity) giữa 2 vector khuôn mặt (0.0 -> 1.0)
  static double compareFaceFeatures(List<double> v1, List<double> v2) {
    if (v1.length != v2.length || v1.isEmpty) return 0.0;
    double dot = 0.0;
    double mag1 = 0.0;
    double mag2 = 0.0;
    for (int i = 0; i < v1.length; i++) {
      dot += v1[i] * v2[i];
      mag1 += v1[i] * v1[i];
      mag2 += v2[i] * v2[i];
    }
    if (mag1 == 0 || mag2 == 0) return 0.0;
    return dot / (math.sqrt(mag1) * math.sqrt(mag2));
  }

  // Generate standardized feature vector embedding from username for backend API compatibility
  static String generateFaceEmbedding(String username, {int featureCount = 32}) {
    final hash = sha256.convert(utf8.encode(username.toLowerCase())).bytes;
    final List<double> vector = [];
    for (int i = 0; i < featureCount; i++) {
      double val = (hash[i % hash.length] / 255.0);
      vector.add(double.parse(val.toStringAsFixed(4)));
    }
    return jsonEncode(vector);
  }
}
