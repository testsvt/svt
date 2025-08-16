-- Schema for Race Hunt Progress (with ranking)

-- Personal progress table
IF OBJECT_ID(N'dbo.Sirin_RaceHunt_Personal', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Sirin_RaceHunt_Personal (
        PlayerSerial INT PRIMARY KEY,
        PlayerName VARCHAR(16) NOT NULL DEFAULT(''),
        RaceCode TINYINT NOT NULL DEFAULT(0),
        PersonalKills INT NOT NULL DEFAULT(0),
        Claimed TINYINT NOT NULL DEFAULT(0),
        UpdatedAt DATETIME2 NOT NULL DEFAULT(SYSUTCDATETIME())
    );
END;
-- Ensure RaceCode exists on existing installations
IF COL_LENGTH('dbo.Sirin_RaceHunt_Personal','RaceCode') IS NULL
BEGIN
    ALTER TABLE dbo.Sirin_RaceHunt_Personal ADD RaceCode TINYINT NOT NULL DEFAULT(0);
END;

-- Race progress table
IF OBJECT_ID(N'dbo.Sirin_RaceHunt_Race', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Sirin_RaceHunt_Race (
        RaceCode TINYINT PRIMARY KEY, -- 0 Bellato, 1 Cora, 2 Accretia
        RaceKills INT NOT NULL DEFAULT(0),
        UpdatedAt DATETIME2 NOT NULL DEFAULT(SYSUTCDATETIME())
    );
    INSERT INTO dbo.Sirin_RaceHunt_Race (RaceCode, RaceKills) VALUES (0,0),(1,0),(2,0);
END;

-- Load personal
IF OBJECT_ID(N'dbo.Sirin_LoadRaceHunt_Personal', N'P') IS NOT NULL DROP PROCEDURE dbo.Sirin_LoadRaceHunt_Personal;
GO
CREATE PROCEDURE dbo.Sirin_LoadRaceHunt_Personal
    @PlayerSerial INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PlayerSerial, PersonalKills FROM dbo.Sirin_RaceHunt_Personal WITH (READCOMMITTEDLOCK)
    WHERE PlayerSerial = @PlayerSerial;
END;
GO

-- Load race
IF OBJECT_ID(N'dbo.Sirin_LoadRaceHunt_Race', N'P') IS NOT NULL DROP PROCEDURE dbo.Sirin_LoadRaceHunt_Race;
GO
CREATE PROCEDURE dbo.Sirin_LoadRaceHunt_Race
    @RaceCode TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT RaceCode, RaceKills FROM dbo.Sirin_RaceHunt_Race WITH (READCOMMITTEDLOCK)
    WHERE RaceCode = @RaceCode;
END;
GO

-- Load claimed
IF OBJECT_ID(N'dbo.Sirin_LoadRaceHunt_Claimed', N'P') IS NOT NULL DROP PROCEDURE dbo.Sirin_LoadRaceHunt_Claimed;
GO
CREATE PROCEDURE dbo.Sirin_LoadRaceHunt_Claimed
    @PlayerSerial INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PlayerSerial, Claimed FROM dbo.Sirin_RaceHunt_Personal WITH (READCOMMITTEDLOCK)
    WHERE PlayerSerial = @PlayerSerial;
END;
GO

-- Increment personal kills (Ex: upsert with name and race)
IF OBJECT_ID(N'dbo.Sirin_IncRaceHunt_PersonalEx', N'P') IS NOT NULL DROP PROCEDURE dbo.Sirin_IncRaceHunt_PersonalEx;
GO
CREATE PROCEDURE dbo.Sirin_IncRaceHunt_PersonalEx
    @PlayerSerial INT,
    @PlayerName VARCHAR(16),
    @RaceCode TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.Sirin_RaceHunt_Personal AS t
    USING (SELECT @PlayerSerial AS PlayerSerial, @PlayerName AS PlayerName, @RaceCode AS RaceCode) AS s
    ON (t.PlayerSerial = s.PlayerSerial)
    WHEN MATCHED THEN
        UPDATE SET PersonalKills = t.PersonalKills + 1,
                   PlayerName = CASE WHEN s.PlayerName IS NOT NULL THEN s.PlayerName ELSE t.PlayerName END,
                   RaceCode = s.RaceCode,
                   UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (PlayerSerial, PlayerName, RaceCode, PersonalKills, Claimed, UpdatedAt)
        VALUES (@PlayerSerial, ISNULL(@PlayerName,''), @RaceCode, 1, 0, SYSUTCDATETIME());
END;
GO

-- Increment race kills
IF OBJECT_ID(N'dbo.Sirin_IncRaceHunt_Race', N'P') IS NOT NULL DROP PROCEDURE dbo.Sirin_IncRaceHunt_Race;
GO
CREATE PROCEDURE dbo.Sirin_IncRaceHunt_Race
    @RaceCode TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Sirin_RaceHunt_Race
      SET RaceKills = RaceKills + 1, UpdatedAt = SYSUTCDATETIME()
      WHERE RaceCode = @RaceCode;
END;
GO

-- Set claimed flag
IF OBJECT_ID(N'dbo.Sirin_SetRaceHunt_Claimed', N'P') IS NOT NULL DROP PROCEDURE dbo.Sirin_SetRaceHunt_Claimed;
GO
CREATE PROCEDURE dbo.Sirin_SetRaceHunt_Claimed
    @PlayerSerial INT
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.Sirin_RaceHunt_Personal AS t
    USING (SELECT @PlayerSerial AS PlayerSerial) AS s
    ON (t.PlayerSerial = s.PlayerSerial)
    WHEN MATCHED THEN
        UPDATE SET Claimed = 1, UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (PlayerSerial, PlayerName, RaceCode, PersonalKills, Claimed, UpdatedAt)
        VALUES (@PlayerSerial, '', 0, 0, 1, SYSUTCDATETIME());
END;
GO

-- Load Top 5 ranking by race (fixed size fields for FetchSelected)
IF OBJECT_ID(N'dbo.Sirin_LoadRaceHunt_Top5', N'P') IS NOT NULL DROP PROCEDURE dbo.Sirin_LoadRaceHunt_Top5;
GO
CREATE PROCEDURE dbo.Sirin_LoadRaceHunt_Top5
    @RaceCode TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (5)
      CAST(RaceCode AS binary(1)) AS RaceCode,
      CAST(PlayerName AS binary(16)) AS PlayerName,
      PersonalKills
    FROM dbo.Sirin_RaceHunt_Personal WITH (READCOMMITTEDLOCK)
    WHERE PlayerName <> '' AND RaceCode = @RaceCode
    ORDER BY PersonalKills DESC, PlayerName ASC;
END;
GO

-- Per-Tab Personal progress table (PlayerSerial + Tab)
IF OBJECT_ID(N'dbo.Sirin_RaceHunt_PersonalTab', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Sirin_RaceHunt_PersonalTab (
        PlayerSerial INT NOT NULL,
        PlayerName VARCHAR(16) NOT NULL DEFAULT(''),
        RaceCode TINYINT NOT NULL DEFAULT(0),
        Tab TINYINT NOT NULL DEFAULT(1), -- 1 or 2
        PersonalKills INT NOT NULL DEFAULT(0),
        Claimed TINYINT NOT NULL DEFAULT(0),
        UpdatedAt DATETIME2 NOT NULL DEFAULT(SYSUTCDATETIME()),
        CONSTRAINT PK_Sirin_RaceHunt_PersonalTab PRIMARY KEY (PlayerSerial, Tab)
    );
END;

-- Per-Tab Race progress table (RaceCode + Tab)
IF OBJECT_ID(N'dbo.Sirin_RaceHunt_RaceTab', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Sirin_RaceHunt_RaceTab (
        RaceCode TINYINT NOT NULL,
        Tab TINYINT NOT NULL DEFAULT(1),
        RaceKills INT NOT NULL DEFAULT(0),
        UpdatedAt DATETIME2 NOT NULL DEFAULT(SYSUTCDATETIME()),
        CONSTRAINT PK_Sirin_RaceHunt_RaceTab PRIMARY KEY (RaceCode, Tab)
    );
    INSERT INTO dbo.Sirin_RaceHunt_RaceTab (RaceCode, Tab, RaceKills)
    SELECT rc.RaceCode, t.Tab, 0
    FROM (VALUES (0),(1),(2)) AS rc(RaceCode)
    CROSS JOIN (VALUES (1),(2)) AS t(Tab)
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.Sirin_RaceHunt_RaceTab x WHERE x.RaceCode = rc.RaceCode AND x.Tab = t.Tab
    );
END;
GO

-- Load personal per tab
IF OBJECT_ID(N'dbo.Sirin_LoadRaceHunt_PersonalTab', N'P') IS NOT NULL DROP PROCEDURE dbo.Sirin_LoadRaceHunt_PersonalTab;
GO
CREATE PROCEDURE dbo.Sirin_LoadRaceHunt_PersonalTab
    @PlayerSerial INT,
    @Tab TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(Tab AS binary(1)) AS Tab, PlayerSerial, PersonalKills
    FROM dbo.Sirin_RaceHunt_PersonalTab WITH (READCOMMITTEDLOCK)
    WHERE PlayerSerial = @PlayerSerial AND Tab = @Tab;
END;
GO

-- Load race per tab
IF OBJECT_ID(N'dbo.Sirin_LoadRaceHunt_RaceTab', N'P') IS NOT NULL DROP PROCEDURE dbo.Sirin_LoadRaceHunt_RaceTab;
GO
CREATE PROCEDURE dbo.Sirin_LoadRaceHunt_RaceTab
    @RaceCode TINYINT,
    @Tab TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(Tab AS binary(1)) AS Tab, CAST(RaceCode AS binary(1)) AS RaceCode, RaceKills
    FROM dbo.Sirin_RaceHunt_RaceTab WITH (READCOMMITTEDLOCK)
    WHERE RaceCode = @RaceCode AND Tab = @Tab;
END;
GO

-- Load claimed per tab
IF OBJECT_ID(N'dbo.Sirin_LoadRaceHunt_ClaimedTab', N'P') IS NOT NULL DROP PROCEDURE dbo.Sirin_LoadRaceHunt_ClaimedTab;
GO
CREATE PROCEDURE dbo.Sirin_LoadRaceHunt_ClaimedTab
    @PlayerSerial INT,
    @Tab TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(Tab AS binary(1)) AS Tab, PlayerSerial, CAST(Claimed AS binary(1)) AS Claimed
    FROM dbo.Sirin_RaceHunt_PersonalTab WITH (READCOMMITTEDLOCK)
    WHERE PlayerSerial = @PlayerSerial AND Tab = @Tab;
END;
GO

-- Increment personal per tab (upsert)
IF OBJECT_ID(N'dbo.Sirin_IncRaceHunt_PersonalTab', N'P') IS NOT NULL DROP PROCEDURE dbo.Sirin_IncRaceHunt_PersonalTab;
GO
CREATE PROCEDURE dbo.Sirin_IncRaceHunt_PersonalTab
    @PlayerSerial INT,
    @PlayerName VARCHAR(16),
    @RaceCode TINYINT,
    @Tab TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.Sirin_RaceHunt_PersonalTab AS t
    USING (SELECT @PlayerSerial AS PlayerSerial, @PlayerName AS PlayerName, @RaceCode AS RaceCode, @Tab AS Tab) AS s
    ON (t.PlayerSerial = s.PlayerSerial AND t.Tab = s.Tab)
    WHEN MATCHED THEN
        UPDATE SET PersonalKills = t.PersonalKills + 1,
                   PlayerName = CASE WHEN s.PlayerName IS NOT NULL THEN s.PlayerName ELSE t.PlayerName END,
                   RaceCode = s.RaceCode,
                   UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (PlayerSerial, PlayerName, RaceCode, Tab, PersonalKills, Claimed, UpdatedAt)
        VALUES (@PlayerSerial, ISNULL(@PlayerName,''), @RaceCode, @Tab, 1, 0, SYSUTCDATETIME());
END;
GO

-- Increment race per tab
IF OBJECT_ID(N'dbo.Sirin_IncRaceHunt_RaceTab', N'P') IS NOT NULL DROP PROCEDURE dbo.Sirin_IncRaceHunt_RaceTab;
GO
CREATE PROCEDURE dbo.Sirin_IncRaceHunt_RaceTab
    @RaceCode TINYINT,
    @Tab TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.Sirin_RaceHunt_RaceTab AS t
    USING (SELECT @RaceCode AS RaceCode, @Tab AS Tab) AS s
    ON (t.RaceCode = s.RaceCode AND t.Tab = s.Tab)
    WHEN MATCHED THEN
        UPDATE SET RaceKills = t.RaceKills + 1,
                   UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (RaceCode, Tab, RaceKills, UpdatedAt)
        VALUES (@RaceCode, @Tab, 1, SYSUTCDATETIME());
END;
GO

-- Set claimed per tab
IF OBJECT_ID(N'dbo.Sirin_SetRaceHunt_ClaimedTab', N'P') IS NOT NULL DROP PROCEDURE dbo.Sirin_SetRaceHunt_ClaimedTab;
GO
CREATE PROCEDURE dbo.Sirin_SetRaceHunt_ClaimedTab
    @PlayerSerial INT,
    @Tab TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dbo.Sirin_RaceHunt_PersonalTab AS t
    USING (SELECT @PlayerSerial AS PlayerSerial, @Tab AS Tab) AS s
    ON (t.PlayerSerial = s.PlayerSerial AND t.Tab = s.Tab)
    WHEN MATCHED THEN
        UPDATE SET Claimed = 1, UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (PlayerSerial, PlayerName, RaceCode, Tab, PersonalKills, Claimed, UpdatedAt)
        VALUES (@PlayerSerial, '', 0, @Tab, 0, 1, SYSUTCDATETIME());
END;
GO

-- Load Top 5 per tab
IF OBJECT_ID(N'dbo.Sirin_LoadRaceHunt_Top5Tab', N'P') IS NOT NULL DROP PROCEDURE dbo.Sirin_LoadRaceHunt_Top5Tab;
GO
CREATE PROCEDURE dbo.Sirin_LoadRaceHunt_Top5Tab
    @RaceCode TINYINT,
    @Tab TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (5)
      CAST(@Tab AS binary(1)) AS Tab,
      CAST(RaceCode AS binary(1)) AS RaceCode,
      CAST(PlayerName AS binary(16)) AS PlayerName,
      PersonalKills
    FROM dbo.Sirin_RaceHunt_PersonalTab WITH (READCOMMITTEDLOCK)
    WHERE PlayerName <> '' AND RaceCode = @RaceCode AND Tab = @Tab
    ORDER BY PersonalKills DESC, PlayerName ASC;
END;
GO