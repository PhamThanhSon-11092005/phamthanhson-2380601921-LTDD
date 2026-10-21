namespace AttendanceApi.Models;

public class Role
{
    public int RoleId { get; set; }
    public string RoleName { get; set; } = string.Empty;
    public string? Description { get; set; }
}

public class Department
{
    public int DepartmentId { get; set; }
    public string DepartmentCode { get; set; } = string.Empty;
    public string DepartmentName { get; set; } = string.Empty;
    public string? LocationAddress { get; set; }
    public double? AllowedLatitude { get; set; }
    public double? AllowedLongitude { get; set; }
    public double AllowedRadiusMeter { get; set; } = 150.0;
    public string? AllowedWifiBSSID { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class Shift
{
    public int ShiftId { get; set; }
    public string ShiftName { get; set; } = string.Empty;
    public TimeSpan StartTime { get; set; }
    public TimeSpan EndTime { get; set; }
    public int GracePeriodMinutes { get; set; } = 15;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class User
{
    public int UserId { get; set; }
    public string Username { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string? PhoneNumber { get; set; }
    public string? AvatarUrl { get; set; }
    public int RoleId { get; set; }
    public string? RoleName { get; set; }
    public int? DepartmentId { get; set; }
    public string? DepartmentName { get; set; }
    public int? ShiftId { get; set; }
    public string? ShiftName { get; set; }
    public string? FaceEmbedding { get; set; }
    public string? FaceImageUrl { get; set; }
    public double? CurrentLatitude { get; set; }
    public double? CurrentLongitude { get; set; }
    public DateTime? LocationUpdatedAt { get; set; }
    public bool IsActive { get; set; } = true;
    public bool EmailConfirmed { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class Attendance
{
    public int AttendanceId { get; set; }
    public int UserId { get; set; }
    public string? FullName { get; set; }
    public string? DepartmentName { get; set; }
    public DateTime WorkDate { get; set; }
    public DateTime? CheckInTime { get; set; }
    public DateTime? CheckOutTime { get; set; }
    public double? CheckInLatitude { get; set; }
    public double? CheckInLongitude { get; set; }
    public string? CheckInAddress { get; set; }
    public string? CheckInWifiBSSID { get; set; }
    public double? CheckInFaceMatchPercent { get; set; }
    public string CheckInStatus { get; set; } = "OnTime";
    public double? CheckOutLatitude { get; set; }
    public double? CheckOutLongitude { get; set; }
    public string? CheckOutWifiBSSID { get; set; }
    public string? CheckOutStatus { get; set; }
    public string? Notes { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class LeaveRequest
{
    public int RequestId { get; set; }
    public int UserId { get; set; }
    public string? FullName { get; set; }
    public string RequestType { get; set; } = "NghiPhep"; // NghiPhep, DiTreVeSom, GiaiTrinh
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public string Reason { get; set; } = string.Empty;
    public string Status { get; set; } = "Pending"; // Pending, Approved, Rejected
    public int? ApproverId { get; set; }
    public string? ApproverName { get; set; }
    public string? ApproverComment { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
}

public class VideoCallRoom
{
    public int RoomId { get; set; }
    public string RoomCode { get; set; } = string.Empty;
    public string RoomName { get; set; } = string.Empty;
    public int HostUserId { get; set; }
    public string? HostName { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
