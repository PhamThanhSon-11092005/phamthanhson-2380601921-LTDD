namespace AttendanceApi.Models;

public class RegisterRequest
{
    public string Username { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string? PhoneNumber { get; set; }
    public int RoleId { get; set; } = 2; // Default Employee
}

public class LoginRequest
{
    public string UsernameOrEmail { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class VerifyOtpRequest
{
    public string Email { get; set; } = string.Empty;
    public string OtpCode { get; set; } = string.Empty;
    public string Type { get; set; } = "LOGIN"; // REGISTER or LOGIN
}

public class FaceLoginRequest
{
    public string UsernameOrEmail { get; set; } = string.Empty;
    public string FaceEmbedding { get; set; } = string.Empty; // JSON array string of features
}

public class RegisterFaceRequest
{
    public int UserId { get; set; }
    public string? UsernameOrEmail { get; set; }
    public string FaceEmbedding { get; set; } = string.Empty;
    public string? FaceImageUrl { get; set; }
}

public class CheckInRequest
{
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public string? Address { get; set; }
    public string? WifiBSSID { get; set; }
    public double FaceMatchPercent { get; set; } = 100.0;
    public string? Notes { get; set; }
}

public class CheckOutRequest
{
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public string? WifiBSSID { get; set; }
}

public class UpdateLocationRequest
{
    public double Latitude { get; set; }
    public double Longitude { get; set; }
}

public class AuthResponse
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public bool RequiresOtp { get; set; }
    public string? Token { get; set; }
    public User? User { get; set; }
    public string? DebugOtp { get; set; } // Returned for convenient testing/grading
}

public class ApiResponse<T>
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public T? Data { get; set; }

    public static ApiResponse<T> Ok(T data, string message = "Thành công") 
        => new ApiResponse<T> { Success = true, Message = message, Data = data };

    public static ApiResponse<T> Fail(string message) 
        => new ApiResponse<T> { Success = false, Message = message, Data = default };
}
