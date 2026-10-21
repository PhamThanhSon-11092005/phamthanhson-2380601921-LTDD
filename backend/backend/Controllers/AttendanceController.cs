using System.Security.Claims;
using AttendanceApi.Models;
using AttendanceApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AttendanceApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AttendanceController : ControllerBase
{
    private readonly IAttendanceService _attendanceService;

    public AttendanceController(IAttendanceService attendanceService)
    {
        _attendanceService = attendanceService;
    }

    private int GetCurrentUserId()
    {
        var idClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (int.TryParse(idClaim, out int id)) return id;
        return 2; // Default employee for unauthenticated testing
    }

    [HttpPost("check-in")]
    public async Task<IActionResult> CheckIn([FromBody] CheckInRequest request, [FromQuery] int? userId)
    {
        int targetUserId = userId ?? GetCurrentUserId();
        var result = await _attendanceService.CheckInAsync(targetUserId, request);
        if (!result.Success) return BadRequest(result);
        return Ok(result);
    }

    [HttpPost("check-out")]
    public async Task<IActionResult> CheckOut([FromBody] CheckOutRequest request, [FromQuery] int? userId)
    {
        int targetUserId = userId ?? GetCurrentUserId();
        var result = await _attendanceService.CheckOutAsync(targetUserId, request);
        if (!result.Success) return BadRequest(result);
        return Ok(result);
    }

    [HttpGet("today")]
    public async Task<IActionResult> GetToday([FromQuery] int? userId)
    {
        int targetUserId = userId ?? GetCurrentUserId();
        var result = await _attendanceService.GetTodayAttendanceAsync(targetUserId);
        return Ok(result);
    }

    [HttpGet("my-history")]
    public async Task<IActionResult> GetMyHistory([FromQuery] int? userId, [FromQuery] int? month, [FromQuery] int? year)
    {
        int targetUserId = userId ?? GetCurrentUserId();
        int m = month ?? DateTime.Now.Month;
        int y = year ?? DateTime.Now.Year;
        var result = await _attendanceService.GetUserAttendanceHistoryAsync(targetUserId, m, y);
        return Ok(result);
    }

    [HttpGet("all")]
    public async Task<IActionResult> GetAll([FromQuery] DateTime? date, [FromQuery] int? departmentId)
    {
        var result = await _attendanceService.GetAllAttendancesAsync(date, departmentId);
        return Ok(result);
    }

    [HttpGet("stats")]
    public async Task<IActionResult> GetStats()
    {
        var result = await _attendanceService.GetAttendanceStatsAsync();
        return Ok(result);
    }
}
