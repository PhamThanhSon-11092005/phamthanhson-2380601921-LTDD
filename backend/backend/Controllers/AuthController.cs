using AttendanceApi.Models;
using AttendanceApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace AttendanceApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        var result = await _authService.RegisterAsync(request);
        if (!result.Success)
            return BadRequest(result);
        return Ok(result);
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        var result = await _authService.LoginAsync(request);
        if (!result.Success)
            return BadRequest(result);
        return Ok(result);
    }

    [HttpPost("verify-otp")]
    public async Task<IActionResult> VerifyOtp([FromBody] VerifyOtpRequest request)
    {
        var result = await _authService.VerifyOtpAsync(request);
        if (!result.Success)
            return BadRequest(result);
        return Ok(result);
    }

    [HttpPost("face-login")]
    public async Task<IActionResult> FaceLogin([FromBody] FaceLoginRequest request)
    {
        var result = await _authService.FaceLoginAsync(request);
        if (!result.Success)
            return BadRequest(result);
        return Ok(result);
    }

    [HttpPost("register-face")]
    public async Task<IActionResult> RegisterFace([FromBody] RegisterFaceRequest request)
    {
        var success = await _authService.RegisterFaceAsync(request);
        if (!success)
            return BadRequest(new { success = false, message = "Không thể cập nhật dữ liệu khuôn mặt" });
        return Ok(new { success = true, message = "Đăng ký khuôn mặt thành công!" });
    }
}
