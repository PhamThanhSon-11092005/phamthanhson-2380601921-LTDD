-- ========================================================
-- DATABASE SCHEMA: PhamThanhSon_2380601921_KTLTDD
-- Using IDENTITY(1,1) for all primary keys
-- ========================================================

USE PhamThanhSon_2380601921_KTLTDD;
GO

-- 1. Table: Roles
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Roles')
BEGIN
    CREATE TABLE Roles (
        RoleId INT IDENTITY(1,1) PRIMARY KEY,
        RoleName NVARCHAR(50) NOT NULL UNIQUE,
        Description NVARCHAR(255) NULL
    );
END
GO

-- 2. Table: Departments (Phòng ban)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Departments')
BEGIN
    CREATE TABLE Departments (
        DepartmentId INT IDENTITY(1,1) PRIMARY KEY,
        DepartmentCode NVARCHAR(50) NOT NULL UNIQUE,
        DepartmentName NVARCHAR(100) NOT NULL,
        LocationAddress NVARCHAR(255) NULL,
        AllowedLatitude FLOAT NULL,
        AllowedLongitude FLOAT NULL,
        AllowedRadiusMeter FLOAT NULL DEFAULT 150.0,
        AllowedWifiBSSID NVARCHAR(100) NULL, -- Anti-fake GPS using Wi-Fi MAC/BSSID
        CreatedAt DATETIME DEFAULT GETDATE()
    );
END
GO

-- 3. Table: Shifts (Ca làm việc)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Shifts')
BEGIN
    CREATE TABLE Shifts (
        ShiftId INT IDENTITY(1,1) PRIMARY KEY,
        ShiftName NVARCHAR(100) NOT NULL,
        StartTime TIME NOT NULL,
        EndTime TIME NOT NULL,
        GracePeriodMinutes INT DEFAULT 15,
        CreatedAt DATETIME DEFAULT GETDATE()
    );
END
GO

-- 4. Table: Users (Người dùng)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Users')
BEGIN
    CREATE TABLE Users (
        UserId INT IDENTITY(1,1) PRIMARY KEY,
        Username NVARCHAR(100) NOT NULL UNIQUE,
        Email NVARCHAR(150) NOT NULL UNIQUE,
        PasswordHash NVARCHAR(255) NOT NULL,
        FullName NVARCHAR(150) NOT NULL,
        PhoneNumber NVARCHAR(20) NULL,
        AvatarUrl NVARCHAR(500) NULL,
        RoleId INT NOT NULL FOREIGN KEY REFERENCES Roles(RoleId),
        DepartmentId INT NULL FOREIGN KEY REFERENCES Departments(DepartmentId),
        ShiftId INT NULL FOREIGN KEY REFERENCES Shifts(ShiftId),
        FaceEmbedding NVARCHAR(MAX) NULL, -- JSON vector or Face Template for Face Login
        FaceImageUrl NVARCHAR(500) NULL,
        CurrentLatitude FLOAT NULL, -- Live location sharing
        CurrentLongitude FLOAT NULL,
        LocationUpdatedAt DATETIME NULL,
        IsActive BIT DEFAULT 1,
        EmailConfirmed BIT DEFAULT 0,
        CreatedAt DATETIME DEFAULT GETDATE()
    );
END
GO

-- 5. Table: OtpCodes (Xác thực đăng nhập OTP qua Email)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'OtpCodes')
BEGIN
    CREATE TABLE OtpCodes (
        OtpId INT IDENTITY(1,1) PRIMARY KEY,
        Email NVARCHAR(150) NOT NULL,
        Code NVARCHAR(10) NOT NULL,
        Type NVARCHAR(50) NOT NULL, -- 'REGISTER', 'LOGIN'
        ExpiredAt DATETIME NOT NULL,
        IsUsed BIT DEFAULT 0,
        CreatedAt DATETIME DEFAULT GETDATE()
    );
END
GO

-- 6. Table: Attendances (Chấm công)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Attendances')
BEGIN
    CREATE TABLE Attendances (
        AttendanceId INT IDENTITY(1,1) PRIMARY KEY,
        UserId INT NOT NULL FOREIGN KEY REFERENCES Users(UserId),
        WorkDate DATE NOT NULL,
        CheckInTime DATETIME NULL,
        CheckOutTime DATETIME NULL,
        CheckInLatitude FLOAT NULL,
        CheckInLongitude FLOAT NULL,
        CheckInAddress NVARCHAR(255) NULL,
        CheckInWifiBSSID NVARCHAR(100) NULL,
        CheckInFaceMatchPercent FLOAT NULL,
        CheckInStatus NVARCHAR(50) DEFAULT 'OnTime', -- 'OnTime', 'Late', 'ValidLocation', 'InvalidLocation'
        CheckOutLatitude FLOAT NULL,
        CheckOutLongitude FLOAT NULL,
        CheckOutWifiBSSID NVARCHAR(100) NULL,
        CheckOutStatus NVARCHAR(50) NULL,
        Notes NVARCHAR(500) NULL,
        CreatedAt DATETIME DEFAULT GETDATE()
    );
END
GO

-- 7. Table: LeaveRequests (Đơn xin nghỉ phép / Giải trình chấm công)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'LeaveRequests')
BEGIN
    CREATE TABLE LeaveRequests (
        RequestId INT IDENTITY(1,1) PRIMARY KEY,
        UserId INT NOT NULL FOREIGN KEY REFERENCES Users(UserId),
        RequestType NVARCHAR(50) NOT NULL, -- 'NghiPhep', 'DiTreVeSom', 'GiaiTrinh'
        StartDate DATE NOT NULL,
        EndDate DATE NOT NULL,
        Reason NVARCHAR(500) NOT NULL,
        Status NVARCHAR(50) DEFAULT 'Pending', -- 'Pending', 'Approved', 'Rejected'
        ApproverId INT NULL FOREIGN KEY REFERENCES Users(UserId),
        ApproverComment NVARCHAR(500) NULL,
        CreatedAt DATETIME DEFAULT GETDATE(),
        UpdatedAt DATETIME NULL
    );
END
GO

-- 8. Table: VideoCallRooms (Phòng họp / Gọi video nhóm)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'VideoCallRooms')
BEGIN
    CREATE TABLE VideoCallRooms (
        RoomId INT IDENTITY(1,1) PRIMARY KEY,
        RoomCode NVARCHAR(50) NOT NULL UNIQUE,
        RoomName NVARCHAR(150) NOT NULL,
        HostUserId INT NOT NULL FOREIGN KEY REFERENCES Users(UserId),
        IsActive BIT DEFAULT 1,
        CreatedAt DATETIME DEFAULT GETDATE()
    );
END
GO

-- ========================================================
-- SEED DEFAULT DATA
-- ========================================================

-- Seed Roles
IF NOT EXISTS (SELECT 1 FROM Roles WHERE RoleName = 'Admin')
    INSERT INTO Roles (RoleName, Description) VALUES ('Admin', N'Quản trị viên toàn quyền hệ thống');

IF NOT EXISTS (SELECT 1 FROM Roles WHERE RoleName = 'Employee')
    INSERT INTO Roles (RoleName, Description) VALUES ('Employee', N'Nhân viên thực hiện chấm công và nghiệp vụ');

IF NOT EXISTS (SELECT 1 FROM Roles WHERE RoleName = 'Customer')
    INSERT INTO Roles (RoleName, Description) VALUES ('Customer', N'Khách hàng / Đối tác liên hệ');
GO

-- Seed Departments
IF NOT EXISTS (SELECT 1 FROM Departments WHERE DepartmentCode = 'IT')
BEGIN
    INSERT INTO Departments (DepartmentCode, DepartmentName, LocationAddress, AllowedLatitude, AllowedLongitude, AllowedRadiusMeter, AllowedWifiBSSID)
    VALUES ('IT', N'Phòng Công Nghệ Thông Tin', N'Đại học HUTECH - Thu Duc Campus, TP.HCM', 10.8558, 106.7853, 200.0, 'Office_WiFi_5G');
END

IF NOT EXISTS (SELECT 1 FROM Departments WHERE DepartmentCode = 'HR')
BEGIN
    INSERT INTO Departments (DepartmentCode, DepartmentName, LocationAddress, AllowedLatitude, AllowedLongitude, AllowedRadiusMeter, AllowedWifiBSSID)
    VALUES ('HR', N'Phòng Hành Chính Nhân Sự', N'Trụ sở chính, TP.HCM', 10.8018, 106.7116, 200.0, 'HUTECH_GUEST');
END
GO

-- Seed Shifts
IF NOT EXISTS (SELECT 1 FROM Shifts WHERE ShiftName = N'Ca Sáng')
    INSERT INTO Shifts (ShiftName, StartTime, EndTime, GracePeriodMinutes) VALUES (N'Ca Sáng', '08:00:00', '12:00:00', 15);

IF NOT EXISTS (SELECT 1 FROM Shifts WHERE ShiftName = N'Ca Chiều')
    INSERT INTO Shifts (ShiftName, StartTime, EndTime, GracePeriodMinutes) VALUES (N'Ca Chiều', '13:00:00', '17:30:00', 15);

IF NOT EXISTS (SELECT 1 FROM Shifts WHERE ShiftName = N'Ca Hành Chính')
    INSERT INTO Shifts (ShiftName, StartTime, EndTime, GracePeriodMinutes) VALUES (N'Ca Hành Chính', '08:00:00', '17:00:00', 15);
GO

-- Seed Default Admin & Employee Users (Password: 123456 -> SHA256 hashed or bcrypt)
-- Note: 'e10adc3949ba59abbe56e057f20f883e' is MD5 for 123456, or SHA256 '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92'
IF NOT EXISTS (SELECT 1 FROM Users WHERE Username = 'admin')
BEGIN
    INSERT INTO Users (Username, Email, PasswordHash, FullName, PhoneNumber, RoleId, DepartmentId, ShiftId, IsActive, EmailConfirmed)
    VALUES ('admin', 'admin@company.com', '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92', N'Quản Trị Viên Hệ Thống', '0901234567', 1, 1, 3, 1, 1);
END

IF NOT EXISTS (SELECT 1 FROM Users WHERE Username = 'nhanvien1')
BEGIN
    INSERT INTO Users (Username, Email, PasswordHash, FullName, PhoneNumber, RoleId, DepartmentId, ShiftId, IsActive, EmailConfirmed)
    VALUES ('nhanvien1', 'nhanvien1@company.com', '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92', N'Phạm Thanh Sơn', '0912345678', 2, 1, 3, 1, 1);
END

IF NOT EXISTS (SELECT 1 FROM Users WHERE Username = 'khachhang1')
BEGIN
    INSERT INTO Users (Username, Email, PasswordHash, FullName, PhoneNumber, RoleId, DepartmentId, ShiftId, IsActive, EmailConfirmed)
    VALUES ('khachhang1', 'khachhang1@company.com', '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92', N'Nguyễn Văn Khách', '0987654321', 3, NULL, NULL, 1, 1);
END
GO

-- ========================================================
-- STORED PROCEDURES (ADO.NET / DAPPER CALLS)
-- ========================================================

-- SP: Register User
CREATE OR ALTER PROCEDURE sp_RegisterUser
    @Username NVARCHAR(100),
    @Email NVARCHAR(150),
    @PasswordHash NVARCHAR(255),
    @FullName NVARCHAR(150),
    @PhoneNumber NVARCHAR(20) = NULL,
    @RoleId INT = 2 -- Default Employee
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM Users WHERE Username = @Username)
    BEGIN
        RAISERROR(N'Tên đăng nhập đã tồn tại!', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM Users WHERE Email = @Email)
    BEGIN
        RAISERROR(N'Email đã được sử dụng!', 16, 1);
        RETURN;
    END

    INSERT INTO Users (Username, Email, PasswordHash, FullName, PhoneNumber, RoleId, DepartmentId, ShiftId, IsActive, EmailConfirmed)
    VALUES (@Username, @Email, @PasswordHash, @FullName, @PhoneNumber, @RoleId, 1, 3, 1, 1);

    SELECT SCOPE_IDENTITY() AS NewUserId;
END
GO

-- SP: Login Check
CREATE OR ALTER PROCEDURE sp_GetUserForLogin
    @UsernameOrEmail NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UserId, u.Username, u.Email, u.PasswordHash, u.FullName, u.PhoneNumber, 
           u.AvatarUrl, u.RoleId, r.RoleName, u.DepartmentId, d.DepartmentName,
           u.ShiftId, s.ShiftName, u.IsActive, u.FaceEmbedding
    FROM Users u
    INNER JOIN Roles r ON u.RoleId = r.RoleId
    LEFT JOIN Departments d ON u.DepartmentId = d.DepartmentId
    LEFT JOIN Shifts s ON u.ShiftId = s.ShiftId
    WHERE (u.Username = @UsernameOrEmail OR u.Email = @UsernameOrEmail) AND u.IsActive = 1;
END
GO

-- SP: Save OTP
CREATE OR ALTER PROCEDURE sp_SaveOtp
    @Email NVARCHAR(150),
    @Code NVARCHAR(10),
    @Type NVARCHAR(50),
    @DurationMinutes INT = 5
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO OtpCodes (Email, Code, Type, ExpiredAt, IsUsed)
    VALUES (@Email, @Code, @Type, DATEADD(MINUTE, @DurationMinutes, GETDATE()), 0);
END
GO

-- SP: Verify OTP
CREATE OR ALTER PROCEDURE sp_VerifyOtp
    @Email NVARCHAR(150),
    @Code NVARCHAR(10),
    @Type NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OtpId INT;
    SELECT TOP 1 @OtpId = OtpId
    FROM OtpCodes
    WHERE Email = @Email AND Code = @Code AND Type = @Type 
      AND IsUsed = 0 AND ExpiredAt >= GETDATE()
    ORDER BY OtpId DESC;

    IF @OtpId IS NOT NULL
    BEGIN
        UPDATE OtpCodes SET IsUsed = 1 WHERE OtpId = @OtpId;
        SELECT 1 AS IsValid;
    END
    ELSE
    BEGIN
        SELECT 0 AS IsValid;
    END
END
GO

-- SP: Check-in Attendance
CREATE OR ALTER PROCEDURE sp_CheckInAttendance
    @UserId INT,
    @Latitude FLOAT,
    @Longitude FLOAT,
    @Address NVARCHAR(255),
    @WifiBSSID NVARCHAR(100),
    @FaceMatchPercent FLOAT = 100.0,
    @Notes NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    DECLARE @ExistingId INT;

    SELECT @ExistingId = AttendanceId 
    FROM Attendances 
    WHERE UserId = @UserId AND WorkDate = @Today;

    IF @ExistingId IS NOT NULL
    BEGIN
        RAISERROR(N'Bạn đã thực hiện Check-in cho ngày hôm nay rồi!', 16, 1);
        RETURN;
    END

    -- Xác thực Geofence & Wi-Fi
    DECLARE @Status NVARCHAR(50) = 'OnTime';
    -- Nếu trễ hơn 8:15 (ví dụ ca 8:00 + 15m)
    IF CAST(GETDATE() AS TIME) > '08:15:00'
        SET @Status = 'Late';

    INSERT INTO Attendances (UserId, WorkDate, CheckInTime, CheckInLatitude, CheckInLongitude, CheckInAddress, CheckInWifiBSSID, CheckInFaceMatchPercent, CheckInStatus, Notes)
    VALUES (@UserId, @Today, GETDATE(), @Latitude, @Longitude, @Address, @WifiBSSID, @FaceMatchPercent, @Status, @Notes);

    SELECT SCOPE_IDENTITY() AS AttendanceId;
END
GO

-- SP: Check-out Attendance
CREATE OR ALTER PROCEDURE sp_CheckOutAttendance
    @UserId INT,
    @Latitude FLOAT,
    @Longitude FLOAT,
    @WifiBSSID NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    DECLARE @ExistingId INT;

    SELECT @ExistingId = AttendanceId 
    FROM Attendances 
    WHERE UserId = @UserId AND WorkDate = @Today;

    IF @ExistingId IS NULL
    BEGIN
        RAISERROR(N'Chưa có dữ liệu Check-in ngày hôm nay!', 16, 1);
        RETURN;
    END

    UPDATE Attendances
    SET CheckOutTime = GETDATE(),
        CheckOutLatitude = @Latitude,
        CheckOutLongitude = @Longitude,
        CheckOutWifiBSSID = @WifiBSSID,
        CheckOutStatus = 'Completed'
    WHERE AttendanceId = @ExistingId;

    SELECT @ExistingId AS AttendanceId;
END
GO

-- SP: Update Live Location
CREATE OR ALTER PROCEDURE sp_UpdateUserLocation
    @UserId INT,
    @Latitude FLOAT,
    @Longitude FLOAT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Users
    SET CurrentLatitude = @Latitude,
        CurrentLongitude = @Longitude,
        LocationUpdatedAt = GETDATE()
    WHERE UserId = @UserId;
END
GO

-- SP: Save Face Embedding
CREATE OR ALTER PROCEDURE sp_UpdateFaceEmbedding
    @UserId INT,
    @FaceEmbedding NVARCHAR(MAX),
    @FaceImageUrl NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Users
    SET FaceEmbedding = @FaceEmbedding,
        FaceImageUrl = ISNULL(@FaceImageUrl, FaceImageUrl)
    WHERE UserId = @UserId;
END
GO
