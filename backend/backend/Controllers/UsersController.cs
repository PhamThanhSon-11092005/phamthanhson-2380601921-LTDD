using AttendanceApi.Models;
using AttendanceApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace AttendanceApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly IUserService _userService;

    public UsersController(IUserService userService)
    {
        _userService = userService;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var users = await _userService.GetAllUsersAsync();
        return Ok(ApiResponse<IEnumerable<User>>.Ok(users));
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        var user = await _userService.GetUserByIdAsync(id);
        if (user == null) return NotFound(ApiResponse<User>.Fail("Không tìm thấy người dùng."));
        return Ok(ApiResponse<User>.Ok(user));
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateUserDto dto)
    {
        var user = new User
        {
            Username = dto.Username,
            Email = dto.Email,
            FullName = dto.FullName,
            PhoneNumber = dto.PhoneNumber,
            RoleId = dto.RoleId,
            DepartmentId = dto.DepartmentId,
            ShiftId = dto.ShiftId
        };
        var success = await _userService.CreateUserAsync(user, dto.Password);
        if (!success) return BadRequest(ApiResponse<bool>.Fail("Không thể tạo nhân viên"));
        return Ok(ApiResponse<bool>.Ok(true, "Thêm nhân viên thành công!"));
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(int id, [FromBody] User user)
    {
        user.UserId = id;
        var success = await _userService.UpdateUserAsync(user);
        if (!success) return BadRequest(ApiResponse<bool>.Fail("Không thể cập nhật nhân viên"));
        return Ok(ApiResponse<bool>.Ok(true, "Cập nhật thành công!"));
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        var success = await _userService.DeleteUserAsync(id);
        if (!success) return BadRequest(ApiResponse<bool>.Fail("Không thể xóa nhân viên"));
        return Ok(ApiResponse<bool>.Ok(true, "Đã vô hiệu hóa tài khoản"));
    }

    // 5.b: Chia sẻ vị trí thời gian thực (Live Location Sharing)
    [HttpPost("update-location")]
    public async Task<IActionResult> UpdateLocation([FromBody] UpdateLocationDto dto)
    {
        var success = await _userService.UpdateLocationAsync(dto.UserId, dto.Latitude, dto.Longitude);
        return Ok(new { success });
    }

    [HttpGet("live-locations")]
    public async Task<IActionResult> GetLiveLocations()
    {
        var list = await _userService.GetActiveLocationsAsync();
        return Ok(ApiResponse<IEnumerable<User>>.Ok(list));
    }
}

public class CreateUserDto
{
    public string Username { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = "123456";
    public string FullName { get; set; } = string.Empty;
    public string? PhoneNumber { get; set; }
    public int RoleId { get; set; } = 2;
    public int? DepartmentId { get; set; }
    public int? ShiftId { get; set; }
}

public class UpdateLocationDto
{
    public int UserId { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
}
