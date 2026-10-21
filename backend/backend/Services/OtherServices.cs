using System.Data;
using AttendanceApi.Data;
using AttendanceApi.Models;
using Dapper;

namespace AttendanceApi.Services;

#region User Service
public interface IUserService
{
    Task<IEnumerable<User>> GetAllUsersAsync();
    Task<User?> GetUserByIdAsync(int id);
    Task<bool> CreateUserAsync(User user, string plainPassword);
    Task<bool> UpdateUserAsync(User user);
    Task<bool> DeleteUserAsync(int id);
    Task<bool> UpdateLocationAsync(int userId, double lat, double lng);
    Task<IEnumerable<User>> GetActiveLocationsAsync();
}

public class UserService : IUserService
{
    private readonly IDbConnectionFactory _dbFactory;

    public UserService(IDbConnectionFactory dbFactory) => _dbFactory = dbFactory;

    public async Task<IEnumerable<User>> GetAllUsersAsync()
    {
        using var conn = _dbFactory.CreateConnection();
        return await conn.QueryAsync<User>(
            @"SELECT u.*, r.RoleName, d.DepartmentName, s.ShiftName
              FROM Users u
              LEFT JOIN Roles r ON u.RoleId = r.RoleId
              LEFT JOIN Departments d ON u.DepartmentId = d.DepartmentId
              LEFT JOIN Shifts s ON u.ShiftId = s.ShiftId
              WHERE u.IsActive = 1
              ORDER BY u.UserId DESC"
        );
    }

    public async Task<User?> GetUserByIdAsync(int id)
    {
        using var conn = _dbFactory.CreateConnection();
        return await conn.QuerySingleOrDefaultAsync<User>(
            @"SELECT u.*, r.RoleName, d.DepartmentName, s.ShiftName
              FROM Users u
              LEFT JOIN Roles r ON u.RoleId = r.RoleId
              LEFT JOIN Departments d ON u.DepartmentId = d.DepartmentId
              LEFT JOIN Shifts s ON u.ShiftId = s.ShiftId
              WHERE u.UserId = @Id",
            new { Id = id }
        );
    }

    public async Task<bool> CreateUserAsync(User user, string plainPassword)
    {
        using var conn = _dbFactory.CreateConnection();
        try
        {
            var hash = AuthService.HashPassword(plainPassword);
            string sql = @"
                INSERT INTO Users (Username, Email, PasswordHash, FullName, PhoneNumber, RoleId, DepartmentId, ShiftId, IsActive, EmailConfirmed)
                VALUES (@Username, @Email, @PasswordHash, @FullName, @PhoneNumber, @RoleId, @DepartmentId, @ShiftId, 1, 1)";
            
            int rows = await conn.ExecuteAsync(sql, new
            {
                user.Username,
                user.Email,
                PasswordHash = hash,
                user.FullName,
                user.PhoneNumber,
                user.RoleId,
                DepartmentId = user.DepartmentId ?? 1,
                ShiftId = user.ShiftId ?? 3
            });
            return rows > 0;
        }
        catch (Exception)
        {
            return false;
        }
    }

    public async Task<bool> UpdateUserAsync(User user)
    {
        using var conn = _dbFactory.CreateConnection();
        string sql = @"
            UPDATE Users 
            SET FullName = @FullName, 
                Email = COALESCE(@Email, Email),
                PhoneNumber = @PhoneNumber, 
                RoleId = @RoleId, 
                DepartmentId = COALESCE(@DepartmentId, DepartmentId), 
                ShiftId = COALESCE(@ShiftId, ShiftId),
                IsActive = @IsActive
            WHERE UserId = @UserId";
        int rows = await conn.ExecuteAsync(sql, user);
        return rows > 0;
    }

    public async Task<bool> DeleteUserAsync(int id)
    {
        using var conn = _dbFactory.CreateConnection();
        try
        {
            // Xóa liên kết các bảng con trước để tránh lỗi khóa ngoại Foreign Key
            await conn.ExecuteAsync("DELETE FROM Attendances WHERE UserId = @Id", new { Id = id });
            await conn.ExecuteAsync("DELETE FROM LeaveRequests WHERE UserId = @Id", new { Id = id });
            await conn.ExecuteAsync("UPDATE VideoCallRooms SET HostUserId = 1 WHERE HostUserId = @Id", new { Id = id });
            await conn.ExecuteAsync("DELETE FROM OtpCodes WHERE Email IN (SELECT Email FROM Users WHERE UserId = @Id)", new { Id = id });
            int rows = await conn.ExecuteAsync("DELETE FROM Users WHERE UserId = @Id", new { Id = id });
            return rows > 0;
        }
        catch (Exception)
        {
            // Fallback vô hiệu hóa nếu còn ràng buộc
            int rows = await conn.ExecuteAsync("UPDATE Users SET IsActive = 0 WHERE UserId = @Id", new { Id = id });
            return rows > 0;
        }
    }

    public async Task<bool> UpdateLocationAsync(int userId, double lat, double lng)
    {
        using var conn = _dbFactory.CreateConnection();
        int rows = await conn.ExecuteAsync(
            "sp_UpdateUserLocation",
            new { UserId = userId, Latitude = lat, Longitude = lng },
            commandType: CommandType.StoredProcedure
        );
        return rows > 0;
    }

    public async Task<IEnumerable<User>> GetActiveLocationsAsync()
    {
        using var conn = _dbFactory.CreateConnection();
        return await conn.QueryAsync<User>(
            @"SELECT UserId, FullName, Username, RoleId, CurrentLatitude, CurrentLongitude, LocationUpdatedAt, DepartmentId
              FROM Users
              WHERE CurrentLatitude IS NOT NULL AND CurrentLongitude IS NOT NULL AND IsActive = 1"
        );
    }
}
#endregion

#region Department Service
public interface IDepartmentService
{
    Task<IEnumerable<Department>> GetAllAsync();
    Task<Department?> GetByIdAsync(int id);
    Task<int> CreateAsync(Department dept);
    Task<bool> UpdateAsync(Department dept);
    Task<bool> DeleteAsync(int id);
}

public class DepartmentService : IDepartmentService
{
    private readonly IDbConnectionFactory _dbFactory;
    public DepartmentService(IDbConnectionFactory dbFactory) => _dbFactory = dbFactory;

    public async Task<IEnumerable<Department>> GetAllAsync()
    {
        using var conn = _dbFactory.CreateConnection();
        return await conn.QueryAsync<Department>("SELECT * FROM Departments ORDER BY DepartmentId DESC");
    }

    public async Task<Department?> GetByIdAsync(int id)
    {
        using var conn = _dbFactory.CreateConnection();
        return await conn.QuerySingleOrDefaultAsync<Department>("SELECT * FROM Departments WHERE DepartmentId = @Id", new { Id = id });
    }

    public async Task<int> CreateAsync(Department dept)
    {
        using var conn = _dbFactory.CreateConnection();
        string sql = @"
            INSERT INTO Departments (DepartmentCode, DepartmentName, LocationAddress, AllowedLatitude, AllowedLongitude, AllowedRadiusMeter, AllowedWifiBSSID)
            VALUES (@DepartmentCode, @DepartmentName, @LocationAddress, @AllowedLatitude, @AllowedLongitude, @AllowedRadiusMeter, @AllowedWifiBSSID);
            SELECT CAST(SCOPE_IDENTITY() as int);";
        return await conn.QuerySingleAsync<int>(sql, dept);
    }

    public async Task<bool> UpdateAsync(Department dept)
    {
        using var conn = _dbFactory.CreateConnection();
        string sql = @"
            UPDATE Departments
            SET DepartmentName = @DepartmentName,
                LocationAddress = @LocationAddress,
                AllowedLatitude = @AllowedLatitude,
                AllowedLongitude = @AllowedLongitude,
                AllowedRadiusMeter = @AllowedRadiusMeter,
                AllowedWifiBSSID = @AllowedWifiBSSID
            WHERE DepartmentId = @DepartmentId";
        return await conn.ExecuteAsync(sql, dept) > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        using var conn = _dbFactory.CreateConnection();
        try
        {
            // Bỏ liên kết nhân viên khỏi phòng ban trước khi xóa
            await conn.ExecuteAsync("UPDATE Users SET DepartmentId = NULL WHERE DepartmentId = @Id", new { Id = id });
            return await conn.ExecuteAsync("DELETE FROM Departments WHERE DepartmentId = @Id", new { Id = id }) > 0;
        }
        catch
        {
            return false;
        }
    }
}
#endregion

#region Shift Service
public interface IShiftService
{
    Task<IEnumerable<Shift>> GetAllAsync();
    Task<Shift?> GetByIdAsync(int id);
    Task<int> CreateAsync(Shift shift);
    Task<bool> UpdateAsync(Shift shift);
    Task<bool> DeleteAsync(int id);
}

public class ShiftService : IShiftService
{
    private readonly IDbConnectionFactory _dbFactory;
    public ShiftService(IDbConnectionFactory dbFactory) => _dbFactory = dbFactory;

    public async Task<IEnumerable<Shift>> GetAllAsync()
    {
        using var conn = _dbFactory.CreateConnection();
        return await conn.QueryAsync<Shift>("SELECT * FROM Shifts ORDER BY ShiftId ASC");
    }

    public async Task<Shift?> GetByIdAsync(int id)
    {
        using var conn = _dbFactory.CreateConnection();
        return await conn.QuerySingleOrDefaultAsync<Shift>("SELECT * FROM Shifts WHERE ShiftId = @Id", new { Id = id });
    }

    public async Task<int> CreateAsync(Shift shift)
    {
        using var conn = _dbFactory.CreateConnection();
        string sql = @"
            INSERT INTO Shifts (ShiftName, StartTime, EndTime, GracePeriodMinutes)
            VALUES (@ShiftName, @StartTime, @EndTime, @GracePeriodMinutes);
            SELECT CAST(SCOPE_IDENTITY() as int);";
        return await conn.QuerySingleAsync<int>(sql, shift);
    }

    public async Task<bool> UpdateAsync(Shift shift)
    {
        using var conn = _dbFactory.CreateConnection();
        string sql = @"
            UPDATE Shifts
            SET ShiftName = @ShiftName,
                StartTime = @StartTime,
                EndTime = @EndTime,
                GracePeriodMinutes = @GracePeriodMinutes
            WHERE ShiftId = @ShiftId";
        return await conn.ExecuteAsync(sql, shift) > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        using var conn = _dbFactory.CreateConnection();
        try
        {
            // Bỏ liên kết nhân viên khỏi ca làm việc trước khi xóa
            await conn.ExecuteAsync("UPDATE Users SET ShiftId = NULL WHERE ShiftId = @Id", new { Id = id });
            return await conn.ExecuteAsync("DELETE FROM Shifts WHERE ShiftId = @Id", new { Id = id }) > 0;
        }
        catch
        {
            return false;
        }
    }
}
#endregion

#region Leave Request Service
public interface ILeaveRequestService
{
    Task<IEnumerable<LeaveRequest>> GetAllAsync(string? status);
    Task<IEnumerable<LeaveRequest>> GetByUserIdAsync(int userId);
    Task<int> CreateAsync(LeaveRequest request);
    Task<bool> ReviewAsync(int requestId, int approverId, string status, string? comment);
}

public class LeaveRequestService : ILeaveRequestService
{
    private readonly IDbConnectionFactory _dbFactory;
    public LeaveRequestService(IDbConnectionFactory dbFactory) => _dbFactory = dbFactory;

    public async Task<IEnumerable<LeaveRequest>> GetAllAsync(string? status)
    {
        using var conn = _dbFactory.CreateConnection();
        string sql = @"
            SELECT lr.*, u.FullName, approver.FullName AS ApproverName
            FROM LeaveRequests lr
            JOIN Users u ON lr.UserId = u.UserId
            LEFT JOIN Users approver ON lr.ApproverId = approver.UserId
            WHERE (@Status IS NULL OR lr.Status = @Status)
            ORDER BY lr.RequestId DESC";
        return await conn.QueryAsync<LeaveRequest>(sql, new { Status = status });
    }

    public async Task<IEnumerable<LeaveRequest>> GetByUserIdAsync(int userId)
    {
        using var conn = _dbFactory.CreateConnection();
        string sql = @"
            SELECT lr.*, u.FullName, approver.FullName AS ApproverName
            FROM LeaveRequests lr
            JOIN Users u ON lr.UserId = u.UserId
            LEFT JOIN Users approver ON lr.ApproverId = approver.UserId
            WHERE lr.UserId = @UserId
            ORDER BY lr.RequestId DESC";
        return await conn.QueryAsync<LeaveRequest>(sql, new { UserId = userId });
    }

    public async Task<int> CreateAsync(LeaveRequest request)
    {
        using var conn = _dbFactory.CreateConnection();
        string sql = @"
            INSERT INTO LeaveRequests (UserId, RequestType, StartDate, EndDate, Reason, Status)
            VALUES (@UserId, @RequestType, @StartDate, @EndDate, @Reason, 'Pending');
            SELECT CAST(SCOPE_IDENTITY() as int);";
        return await conn.QuerySingleAsync<int>(sql, request);
    }

    public async Task<bool> ReviewAsync(int requestId, int approverId, string status, string? comment)
    {
        using var conn = _dbFactory.CreateConnection();
        string sql = @"
            UPDATE LeaveRequests
            SET Status = @Status,
                ApproverId = @ApproverId,
                ApproverComment = @Comment,
                UpdatedAt = GETDATE()
            WHERE RequestId = @RequestId";
        return await conn.ExecuteAsync(sql, new { RequestId = requestId, ApproverId = approverId, Status = status, Comment = comment }) > 0;
    }
}
#endregion

#region Video Call Service
public interface IVideoCallService
{
    Task<IEnumerable<VideoCallRoom>> GetActiveRoomsAsync();
    Task<VideoCallRoom> CreateRoomAsync(string roomName, int hostUserId);
    Task<bool> CloseRoomAsync(int roomId);
}

public class VideoCallService : IVideoCallService
{
    private readonly IDbConnectionFactory _dbFactory;
    public VideoCallService(IDbConnectionFactory dbFactory) => _dbFactory = dbFactory;

    public async Task<IEnumerable<VideoCallRoom>> GetActiveRoomsAsync()
    {
        using var conn = _dbFactory.CreateConnection();
        return await conn.QueryAsync<VideoCallRoom>(
            @"SELECT r.*, u.FullName AS HostName 
              FROM VideoCallRooms r
              JOIN Users u ON r.HostUserId = u.UserId
              WHERE r.IsActive = 1
              ORDER BY r.RoomId DESC"
        );
    }

    public async Task<VideoCallRoom> CreateRoomAsync(string roomName, int hostUserId)
    {
        using var conn = _dbFactory.CreateConnection();
        var code = "ROOM-" + Guid.NewGuid().ToString().Substring(0, 8).ToUpper();
        string sql = @"
            INSERT INTO VideoCallRooms (RoomCode, RoomName, HostUserId, IsActive)
            VALUES (@RoomCode, @RoomName, @HostUserId, 1);
            SELECT CAST(SCOPE_IDENTITY() as int);";
        int id = await conn.QuerySingleAsync<int>(sql, new { RoomCode = code, RoomName = roomName, HostUserId = hostUserId });
        return new VideoCallRoom { RoomId = id, RoomCode = code, RoomName = roomName, HostUserId = hostUserId, IsActive = true };
    }

    public async Task<bool> CloseRoomAsync(int roomId)
    {
        using var conn = _dbFactory.CreateConnection();
        return await conn.ExecuteAsync("UPDATE VideoCallRooms SET IsActive = 0 WHERE RoomId = @Id", new { Id = roomId }) > 0;
    }
}
#endregion
