class UserModel {
  final int userId;
  final String username;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String? avatarUrl;
  final int roleId;
  final String roleName;
  final int? departmentId;
  final String? departmentName;
  final int? shiftId;
  final String? shiftName;
  final double? currentLatitude;
  final double? currentLongitude;

  UserModel({
    required this.userId,
    required this.username,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.avatarUrl,
    required this.roleId,
    required this.roleName,
    this.departmentId,
    this.departmentName,
    this.shiftId,
    this.shiftName,
    this.currentLatitude,
    this.currentLongitude,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] ?? json['UserId'] ?? 0,
      username: json['username'] ?? json['Username'] ?? '',
      email: json['email'] ?? json['Email'] ?? '',
      fullName: json['fullName'] ?? json['FullName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? json['PhoneNumber'],
      avatarUrl: json['avatarUrl'] ?? json['AvatarUrl'],
      roleId: json['roleId'] ?? json['RoleId'] ?? 2,
      roleName: json['roleName'] ?? json['RoleName'] ?? 'Employee',
      departmentId: json['departmentId'] ?? json['DepartmentId'],
      departmentName: json['departmentName'] ?? json['DepartmentName'],
      shiftId: json['shiftId'] ?? json['ShiftId'],
      shiftName: json['shiftName'] ?? json['ShiftName'],
      currentLatitude: (json['currentLatitude'] ?? json['CurrentLatitude'] as num?)?.toDouble(),
      currentLongitude: (json['currentLongitude'] ?? json['CurrentLongitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'username': username,
    'email': email,
    'fullName': fullName,
    'phoneNumber': phoneNumber,
    'avatarUrl': avatarUrl,
    'roleId': roleId,
    'roleName': roleName,
    'departmentId': departmentId,
    'departmentName': departmentName,
    'shiftId': shiftId,
    'shiftName': shiftName,
  };

  bool get isAdmin => roleName.toLowerCase() == 'admin' || roleId == 1;
  bool get isEmployee => roleName.toLowerCase() == 'employee' || roleId == 2;
  bool get isCustomer => roleName.toLowerCase() == 'customer' || roleId == 3;
}

class AttendanceModel {
  final int attendanceId;
  final int userId;
  final String? fullName;
  final String? departmentName;
  final DateTime workDate;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final String? checkInAddress;
  final String? checkInWifiBSSID;
  final double? checkInFaceMatchPercent;
  final String checkInStatus;
  final String? checkOutStatus;
  final String? notes;

  AttendanceModel({
    required this.attendanceId,
    required this.userId,
    this.fullName,
    this.departmentName,
    required this.workDate,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkInAddress,
    this.checkInWifiBSSID,
    this.checkInFaceMatchPercent,
    required this.checkInStatus,
    this.checkOutStatus,
    this.notes,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      attendanceId: json['attendanceId'] ?? json['AttendanceId'] ?? 0,
      userId: json['userId'] ?? json['UserId'] ?? 0,
      fullName: json['fullName'] ?? json['FullName'],
      departmentName: json['departmentName'] ?? json['DepartmentName'],
      workDate: DateTime.tryParse(json['workDate'] ?? json['WorkDate'] ?? '') ?? DateTime.now(),
      checkInTime: json['checkInTime'] != null ? DateTime.tryParse(json['checkInTime']) : null,
      checkOutTime: json['checkOutTime'] != null ? DateTime.tryParse(json['checkOutTime']) : null,
      checkInLatitude: (json['checkInLatitude'] ?? json['CheckInLatitude'] as num?)?.toDouble(),
      checkInLongitude: (json['checkInLongitude'] ?? json['CheckInLongitude'] as num?)?.toDouble(),
      checkInAddress: json['checkInAddress'] ?? json['CheckInAddress'],
      checkInWifiBSSID: json['checkInWifiBSSID'] ?? json['CheckInWifiBSSID'],
      checkInFaceMatchPercent: (json['checkInFaceMatchPercent'] ?? json['CheckInFaceMatchPercent'] as num?)?.toDouble(),
      checkInStatus: json['checkInStatus'] ?? json['CheckInStatus'] ?? 'OnTime',
      checkOutStatus: json['checkOutStatus'] ?? json['CheckOutStatus'],
      notes: json['notes'] ?? json['Notes'],
    );
  }
}

class DepartmentModel {
  final int departmentId;
  final String departmentCode;
  final String departmentName;
  final String? locationAddress;
  final double? allowedLatitude;
  final double? allowedLongitude;
  final double allowedRadiusMeter;
  final String? allowedWifiBSSID;

  DepartmentModel({
    required this.departmentId,
    required this.departmentCode,
    required this.departmentName,
    this.locationAddress,
    this.allowedLatitude,
    this.allowedLongitude,
    required this.allowedRadiusMeter,
    this.allowedWifiBSSID,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      departmentId: json['departmentId'] ?? json['DepartmentId'] ?? 0,
      departmentCode: json['departmentCode'] ?? json['DepartmentCode'] ?? '',
      departmentName: json['departmentName'] ?? json['DepartmentName'] ?? '',
      locationAddress: json['locationAddress'] ?? json['LocationAddress'],
      allowedLatitude: (json['allowedLatitude'] ?? json['AllowedLatitude'] as num?)?.toDouble(),
      allowedLongitude: (json['allowedLongitude'] ?? json['AllowedLongitude'] as num?)?.toDouble(),
      allowedRadiusMeter: (json['allowedRadiusMeter'] ?? json['AllowedRadiusMeter'] as num?)?.toDouble() ?? 150.0,
      allowedWifiBSSID: json['allowedWifiBSSID'] ?? json['AllowedWifiBSSID'],
    );
  }

  Map<String, dynamic> toJson() => {
    'departmentId': departmentId,
    'departmentCode': departmentCode,
    'departmentName': departmentName,
    'locationAddress': locationAddress,
    'allowedLatitude': allowedLatitude,
    'allowedLongitude': allowedLongitude,
    'allowedRadiusMeter': allowedRadiusMeter,
    'allowedWifiBSSID': allowedWifiBSSID,
  };
}

class ShiftModel {
  final int shiftId;
  final String shiftName;
  final String startTime;
  final String endTime;
  final int gracePeriodMinutes;

  ShiftModel({
    required this.shiftId,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    required this.gracePeriodMinutes,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      shiftId: json['shiftId'] ?? json['ShiftId'] ?? 0,
      shiftName: json['shiftName'] ?? json['ShiftName'] ?? '',
      startTime: json['startTime'] ?? json['StartTime'] ?? '',
      endTime: json['endTime'] ?? json['EndTime'] ?? '',
      gracePeriodMinutes: json['gracePeriodMinutes'] ?? json['GracePeriodMinutes'] ?? 15,
    );
  }

  Map<String, dynamic> toJson() => {
    'shiftId': shiftId,
    'shiftName': shiftName,
    'startTime': startTime,
    'endTime': endTime,
    'gracePeriodMinutes': gracePeriodMinutes,
  };
}

class LeaveRequestModel {
  final int requestId;
  final int userId;
  final String? fullName;
  final String requestType;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status;
  final int? approverId;
  final String? approverName;
  final String? approverComment;

  LeaveRequestModel({
    required this.requestId,
    required this.userId,
    this.fullName,
    required this.requestType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    this.approverId,
    this.approverName,
    this.approverComment,
  });

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      requestId: json['requestId'] ?? json['RequestId'] ?? 0,
      userId: json['userId'] ?? json['UserId'] ?? 0,
      fullName: json['fullName'] ?? json['FullName'],
      requestType: json['requestType'] ?? json['RequestType'] ?? 'NghiPhep',
      startDate: DateTime.tryParse(json['startDate'] ?? json['StartDate'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate'] ?? json['EndDate'] ?? '') ?? DateTime.now(),
      reason: json['reason'] ?? json['Reason'] ?? '',
      status: json['status'] ?? json['Status'] ?? 'Pending',
      approverId: json['approverId'] ?? json['ApproverId'],
      approverName: json['approverName'] ?? json['ApproverName'],
      approverComment: json['approverComment'] ?? json['ApproverComment'],
    );
  }
}

class VideoRoomModel {
  final int roomId;
  final String roomCode;
  final String roomName;
  final int hostUserId;
  final String? hostName;
  final bool isActive;

  VideoRoomModel({
    required this.roomId,
    required this.roomCode,
    required this.roomName,
    required this.hostUserId,
    this.hostName,
    required this.isActive,
  });

  factory VideoRoomModel.fromJson(Map<String, dynamic> json) {
    return VideoRoomModel(
      roomId: json['roomId'] ?? json['RoomId'] ?? 0,
      roomCode: json['roomCode'] ?? json['RoomCode'] ?? '',
      roomName: json['roomName'] ?? json['RoomName'] ?? '',
      hostUserId: json['hostUserId'] ?? json['HostUserId'] ?? 0,
      hostName: json['hostName'] ?? json['HostName'],
      isActive: json['isActive'] ?? json['IsActive'] ?? true,
    );
  }
}
