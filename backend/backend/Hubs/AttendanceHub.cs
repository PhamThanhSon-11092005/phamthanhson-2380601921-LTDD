using Microsoft.AspNetCore.SignalR;

namespace AttendanceApi.Hubs;

public class AttendanceHub : Hub
{
    private readonly ILogger<AttendanceHub> _logger;

    public AttendanceHub(ILogger<AttendanceHub> logger)
    {
        _logger = logger;
    }

    // 1. Chia sẻ vị trí thời gian thực (Real-time Live Location Sharing)
    public async Task UpdateLocation(int userId, string fullName, double latitude, double longitude)
    {
        _logger.LogInformation("Location update from user {UserId} ({FullName}): {Lat}, {Lng}", userId, fullName, latitude, longitude);
        await Clients.Others.SendAsync("ReceiveLocationUpdate", new
        {
            userId,
            fullName,
            latitude,
            longitude,
            updatedAt = DateTime.UtcNow
        });
    }

    // 2. Gọi video nhóm (Group Video Call Signaling via WebRTC / SignalR)
    public async Task JoinVideoRoom(string roomCode, int userId, string userName)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, roomCode);
        _logger.LogInformation("User {UserName} ({UserId}) joined video room {RoomCode}", userName, userId, roomCode);
        await Clients.Group(roomCode).SendAsync("UserJoinedRoom", new
        {
            connectionId = Context.ConnectionId,
            userId,
            userName,
            joinedAt = DateTime.UtcNow
        });
    }

    public async Task LeaveVideoRoom(string roomCode, int userId, string userName)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, roomCode);
        _logger.LogInformation("User {UserName} ({UserId}) left video room {RoomCode}", userName, userId, roomCode);
        await Clients.Group(roomCode).SendAsync("UserLeftRoom", new
        {
            connectionId = Context.ConnectionId,
            userId,
            userName
        });
    }

    // Gửi WebRTC Offer / Answer / ICE Candidate cho các thành viên trong phòng
    public async Task SendSignal(string roomCode, object signalData)
    {
        await Clients.OthersInGroup(roomCode).SendAsync("ReceiveSignal", new
        {
            senderConnectionId = Context.ConnectionId,
            data = signalData
        });
    }

    // Gửi tin nhắn chat trong phòng họp video
    public async Task SendRoomMessage(string roomCode, string senderName, string message)
    {
        await Clients.Group(roomCode).SendAsync("ReceiveRoomMessage", new
        {
            senderName,
            message,
            timestamp = DateTime.UtcNow
        });
    }
}
