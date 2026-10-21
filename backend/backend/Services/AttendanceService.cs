using System.Data;
using AttendanceApi.Data;
using AttendanceApi.Models;
using Dapper;

namespace AttendanceApi.Services;

public interface IAttendanceService
{
    Task<ApiResponse<Attendance>> CheckInAsync(int userId, CheckInRequest request);
    Task<ApiResponse<Attendance>> CheckOutAsync(int userId, CheckOutRequest request);
    Task<ApiResponse<Attendance?>> GetTodayAttendanceAsync(int userId);
    Task<ApiResponse<IEnumerable<Attendance>>> GetUserAttendanceHistoryAsync(int userId, int month, int year);
    Task<ApiResponse<IEnumerable<Attendance>>> GetAllAttendancesAsync(DateTime? date, int? departmentId);
    Task<ApiResponse<object>> GetAttendanceStatsAsync();
}

public class AttendanceService : IAttendanceService
{
    private readonly IDbConnectionFactory _dbFactory;
    private readonly ILogger<AttendanceService> _logger;

    public AttendanceService(IDbConnectionFactory dbFactory, ILogger<AttendanceService> logger)
    {
        _dbFactory = dbFactory;
        _logger = logger;
    }

    public async Task<ApiResponse<Attendance>> CheckInAsync(int userId, CheckInRequest request)
    {
        using var conn = _dbFactory.CreateConnection();
        try
        {
            // Check Geofence & Wi-Fi against user's Department
            var user = await conn.QuerySingleOrDefaultAsync<User>(
                @"SELECT u.*, d.AllowedLatitude, d.AllowedLongitude, d.AllowedRadiusMeter, d.AllowedWifiBSSID 
                  FROM Users u
                  LEFT JOIN Departments d ON u.DepartmentId = d.DepartmentId
                  WHERE u.UserId = @UserId",
                new { UserId = userId }
            );

            if (user == null)
            {
                return ApiResponse<Attendance>.Fail("Không tìm thấy thông tin nhân viên.");
            }

            // Anti-fake GPS validation
            string status = "OnTime";
            bool locationValid = true;

            // 1. Kiểm tra tọa độ GPS nếu phòng ban có cấu hình
            if (user.CurrentLatitude.HasValue || (request.Latitude != 0 && request.Longitude != 0))
            {
                var dept = await conn.QuerySingleOrDefaultAsync<Department>(
                    "SELECT * FROM Departments WHERE DepartmentId = @DeptId",
                    new { DeptId = user.DepartmentId }
                );

                if (dept != null && dept.AllowedLatitude.HasValue && dept.AllowedLongitude.HasValue)
                {
                    double dist = CalculateDistanceMeters(
                        request.Latitude, request.Longitude,
                        dept.AllowedLatitude.Value, dept.AllowedLongitude.Value
                    );

                    if (dist > dept.AllowedRadiusMeter)
                    {
                        locationValid = false;
                        status = "OutOfRange"; // Ngoài bán kính văn phòng
                    }
                }

                // 2. Kiểm tra Smart Wi-Fi BSSID (Tính năng độc quyền chống Fake GPS)
                if (dept != null && !string.IsNullOrWhiteSpace(dept.AllowedWifiBSSID))
                {
                    if (!string.Equals(request.WifiBSSID, dept.AllowedWifiBSSID, StringComparison.OrdinalIgnoreCase))
                    {
                        if (!locationValid)
                        {
                            status = "InvalidLocation_WifiMismatch";
                        }
                    }
                }
            }

            if (!locationValid)
            {
                request.Notes = (string.IsNullOrWhiteSpace(request.Notes) ? "" : request.Notes + " | ") + $"[Cảnh báo: {status}]";
            }

            var parameters = new DynamicParameters();
            parameters.Add("@UserId", userId);
            parameters.Add("@Latitude", request.Latitude);
            parameters.Add("@Longitude", request.Longitude);
            parameters.Add("@Address", request.Address ?? "Văn phòng");
            parameters.Add("@WifiBSSID", request.WifiBSSID);
            parameters.Add("@FaceMatchPercent", request.FaceMatchPercent);
            parameters.Add("@Notes", request.Notes);

            var attendanceId = await conn.QuerySingleOrDefaultAsync<int>(
                "sp_CheckInAttendance",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            // Fetch created record
            var result = await conn.QuerySingleOrDefaultAsync<Attendance>(
                "SELECT * FROM Attendances WHERE AttendanceId = @Id",
                new { Id = attendanceId }
            );

            return ApiResponse<Attendance>.Ok(result!, "Điểm danh Check-in thành công!");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi check-in");
            return ApiResponse<Attendance>.Fail(ex.Message);
        }
    }

    public async Task<ApiResponse<Attendance>> CheckOutAsync(int userId, CheckOutRequest request)
    {
        using var conn = _dbFactory.CreateConnection();
        try
        {
            var parameters = new DynamicParameters();
            parameters.Add("@UserId", userId);
            parameters.Add("@Latitude", request.Latitude);
            parameters.Add("@Longitude", request.Longitude);
            parameters.Add("@WifiBSSID", request.WifiBSSID);

            var attendanceId = await conn.QuerySingleOrDefaultAsync<int>(
                "sp_CheckOutAttendance",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            var result = await conn.QuerySingleOrDefaultAsync<Attendance>(
                "SELECT * FROM Attendances WHERE AttendanceId = @Id",
                new { Id = attendanceId }
            );

            return ApiResponse<Attendance>.Ok(result!, "Check-out hoàn tất. Hẹn gặp lại bạn!");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi check-out");
            return ApiResponse<Attendance>.Fail(ex.Message);
        }
    }

    public async Task<ApiResponse<Attendance?>> GetTodayAttendanceAsync(int userId)
    {
        using var conn = _dbFactory.CreateConnection();
        var record = await conn.QuerySingleOrDefaultAsync<Attendance>(
            "SELECT * FROM Attendances WHERE UserId = @UserId AND WorkDate = CAST(GETDATE() AS DATE)",
            new { UserId = userId }
        );
        return ApiResponse<Attendance?>.Ok(record);
    }

    public async Task<ApiResponse<IEnumerable<Attendance>>> GetUserAttendanceHistoryAsync(int userId, int month, int year)
    {
        using var conn = _dbFactory.CreateConnection();
        var records = await conn.QueryAsync<Attendance>(
            @"SELECT a.*, u.FullName 
              FROM Attendances a 
              JOIN Users u ON a.UserId = u.UserId
              WHERE a.UserId = @UserId 
                AND MONTH(a.WorkDate) = @Month 
                AND YEAR(a.WorkDate) = @Year
              ORDER BY a.WorkDate DESC",
            new { UserId = userId, Month = month, Year = year }
        );
        return ApiResponse<IEnumerable<Attendance>>.Ok(records);
    }

    public async Task<ApiResponse<IEnumerable<Attendance>>> GetAllAttendancesAsync(DateTime? date, int? departmentId)
    {
        using var conn = _dbFactory.CreateConnection();
        var filterDate = date?.Date ?? DateTime.Today;

        string sql = @"
            SELECT a.*, u.FullName, d.DepartmentName
            FROM Attendances a
            JOIN Users u ON a.UserId = u.UserId
            LEFT JOIN Departments d ON u.DepartmentId = d.DepartmentId
            WHERE a.WorkDate = @FilterDate
              AND (@DepartmentId IS NULL OR u.DepartmentId = @DepartmentId)
            ORDER BY a.CheckInTime DESC";

        var records = await conn.QueryAsync<Attendance>(sql, new { FilterDate = filterDate, DepartmentId = departmentId });
        return ApiResponse<IEnumerable<Attendance>>.Ok(records);
    }

    public async Task<ApiResponse<object>> GetAttendanceStatsAsync()
    {
        using var conn = _dbFactory.CreateConnection();
        int totalEmployees = await conn.ExecuteScalarAsync<int>("SELECT COUNT(1) FROM Users WHERE RoleId IN (1, 2) AND IsActive = 1");
        int checkedInToday = await conn.ExecuteScalarAsync<int>("SELECT COUNT(DISTINCT UserId) FROM Attendances WHERE WorkDate = CAST(GETDATE() AS DATE) AND CheckInTime IS NOT NULL");
        int checkedOutToday = await conn.ExecuteScalarAsync<int>("SELECT COUNT(DISTINCT UserId) FROM Attendances WHERE WorkDate = CAST(GETDATE() AS DATE) AND CheckOutTime IS NOT NULL");
        int pendingLeaves = await conn.ExecuteScalarAsync<int>("SELECT COUNT(1) FROM LeaveRequests WHERE Status = 'Pending'");

        return ApiResponse<object>.Ok(new
        {
            TotalEmployees = totalEmployees,
            CheckedInToday = checkedInToday,
            CheckedOutToday = checkedOutToday,
            AbsentToday = Math.Max(0, totalEmployees - checkedInToday),
            PendingLeaves = pendingLeaves
        });
    }

    // Haversine distance in meters
    private static double CalculateDistanceMeters(double lat1, double lon1, double lat2, double lon2)
    {
        const double R = 6371e3; // metres
        double phi1 = lat1 * Math.PI / 180;
        double phi2 = lat2 * Math.PI / 180;
        double deltaPhi = (lat2 - lat1) * Math.PI / 180;
        double deltaLambda = (lon2 - lon1) * Math.PI / 180;

        double a = Math.Sin(deltaPhi / 2) * Math.Sin(deltaPhi / 2) +
                  Math.Cos(phi1) * Math.Cos(phi2) *
                  Math.Sin(deltaLambda / 2) * Math.Sin(deltaLambda / 2);
        double c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));

        return R * c;
    }
}
