using AttendanceApi.Models;
using AttendanceApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace AttendanceApi.Controllers;

#region Departments Controller
[ApiController]
[Route("api/[controller]")]
public class DepartmentsController : ControllerBase
{
    private readonly IDepartmentService _departmentService;
    public DepartmentsController(IDepartmentService departmentService) => _departmentService = departmentService;

    [HttpGet]
    public async Task<IActionResult> GetAll() => Ok(ApiResponse<IEnumerable<Department>>.Ok(await _departmentService.GetAllAsync()));

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        var dept = await _departmentService.GetByIdAsync(id);
        if (dept == null) return NotFound(ApiResponse<Department>.Fail("Không tìm thấy phòng ban."));
        return Ok(ApiResponse<Department>.Ok(dept));
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] Department dept)
    {
        int id = await _departmentService.CreateAsync(dept);
        dept.DepartmentId = id;
        return Ok(ApiResponse<Department>.Ok(dept, "Tạo phòng ban thành công!"));
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(int id, [FromBody] Department dept)
    {
        dept.DepartmentId = id;
        var success = await _departmentService.UpdateAsync(dept);
        if (!success) return BadRequest(ApiResponse<bool>.Fail("Không thể cập nhật phòng ban"));
        return Ok(ApiResponse<bool>.Ok(true, "Cập nhật thành công!"));
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        var success = await _departmentService.DeleteAsync(id);
        if (!success) return BadRequest(ApiResponse<bool>.Fail("Không thể xóa phòng ban"));
        return Ok(ApiResponse<bool>.Ok(true, "Xóa phòng ban thành công!"));
    }
}
#endregion

#region Shifts Controller
[ApiController]
[Route("api/[controller]")]
public class ShiftsController : ControllerBase
{
    private readonly IShiftService _shiftService;
    public ShiftsController(IShiftService shiftService) => _shiftService = shiftService;

    [HttpGet]
    public async Task<IActionResult> GetAll() => Ok(ApiResponse<IEnumerable<Shift>>.Ok(await _shiftService.GetAllAsync()));

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        var shift = await _shiftService.GetByIdAsync(id);
        if (shift == null) return NotFound(ApiResponse<Shift>.Fail("Không tìm thấy ca làm việc."));
        return Ok(ApiResponse<Shift>.Ok(shift));
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] Shift shift)
    {
        int id = await _shiftService.CreateAsync(shift);
        shift.ShiftId = id;
        return Ok(ApiResponse<Shift>.Ok(shift, "Tạo ca làm việc thành công!"));
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(int id, [FromBody] Shift shift)
    {
        shift.ShiftId = id;
        var success = await _shiftService.UpdateAsync(shift);
        if (!success) return BadRequest(ApiResponse<bool>.Fail("Không thể cập nhật ca làm việc"));
        return Ok(ApiResponse<bool>.Ok(true, "Cập nhật thành công!"));
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        var success = await _shiftService.DeleteAsync(id);
        if (!success) return BadRequest(ApiResponse<bool>.Fail("Không thể xóa ca làm việc"));
        return Ok(ApiResponse<bool>.Ok(true, "Xóa ca thành công!"));
    }
}
#endregion

#region LeaveRequests Controller
[ApiController]
[Route("api/[controller]")]
public class LeaveRequestsController : ControllerBase
{
    private readonly ILeaveRequestService _leaveService;
    public LeaveRequestsController(ILeaveRequestService leaveService) => _leaveService = leaveService;

    [HttpGet]
    public async Task<IActionResult> GetAll([FromQuery] string? status)
    {
        var list = await _leaveService.GetAllAsync(status);
        return Ok(ApiResponse<IEnumerable<LeaveRequest>>.Ok(list));
    }

    [HttpGet("my-requests")]
    public async Task<IActionResult> GetMyRequests([FromQuery] int userId)
    {
        var list = await _leaveService.GetByUserIdAsync(userId);
        return Ok(ApiResponse<IEnumerable<LeaveRequest>>.Ok(list));
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] LeaveRequest request)
    {
        int id = await _leaveService.CreateAsync(request);
        request.RequestId = id;
        return Ok(ApiResponse<LeaveRequest>.Ok(request, "Đã gửi đơn thành công!"));
    }

    [HttpPut("{id}/review")]
    public async Task<IActionResult> Review(int id, [FromBody] ReviewRequestDto dto)
    {
        var success = await _leaveService.ReviewAsync(id, dto.ApproverId, dto.Status, dto.Comment);
        if (!success) return BadRequest(ApiResponse<bool>.Fail("Không thể cập nhật trạng thái đơn"));
        return Ok(ApiResponse<bool>.Ok(true, "Duyệt đơn thành công!"));
    }
}

public class ReviewRequestDto
{
    public int ApproverId { get; set; }
    public string Status { get; set; } = "Approved"; // Approved or Rejected
    public string? Comment { get; set; }
}
#endregion

#region VideoCall Controller (5.c: Gọi video nhóm)
[ApiController]
[Route("api/[controller]")]
public class VideoCallController : ControllerBase
{
    private readonly IVideoCallService _videoService;
    public VideoCallController(IVideoCallService videoService) => _videoService = videoService;

    [HttpGet("rooms")]
    public async Task<IActionResult> GetRooms()
    {
        var rooms = await _videoService.GetActiveRoomsAsync();
        return Ok(ApiResponse<IEnumerable<VideoCallRoom>>.Ok(rooms));
    }

    [HttpPost("create")]
    public async Task<IActionResult> CreateRoom([FromBody] CreateRoomDto dto)
    {
        var room = await _videoService.CreateRoomAsync(dto.RoomName, dto.HostUserId);
        return Ok(ApiResponse<VideoCallRoom>.Ok(room, "Tạo phòng họp thành công!"));
    }

    [HttpPost("{id}/close")]
    public async Task<IActionResult> CloseRoom(int id)
    {
        var success = await _videoService.CloseRoomAsync(id);
        return Ok(ApiResponse<bool>.Ok(success, "Đã đóng phòng họp."));
    }
}

public class CreateRoomDto
{
    public string RoomName { get; set; } = "Họp giao ban chấm công";
    public int HostUserId { get; set; } = 1;
}
#endregion
