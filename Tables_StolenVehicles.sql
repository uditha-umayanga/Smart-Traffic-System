-- Stolen vehicle register (optional: server.js also creates this table automatically on start-up)
USE Smart_traffic_System;
GO

IF OBJECT_ID('dbo.StolenVehicles', 'U') IS NULL
CREATE TABLE dbo.StolenVehicles (
    StolenID           INT IDENTITY(1,1) PRIMARY KEY,
    RegistrationPlate  VARCHAR(20)  NOT NULL,
    PlateNorm          VARCHAR(20)  NOT NULL,   -- plate without spaces/dashes, upper case
    PlateCore          VARCHAR(20)  NOT NULL,   -- PlateNorm without province prefix (WP, CP, SP ...)
    MakeAndModel       VARCHAR(100) NULL,
    Colour             VARCHAR(50)  NULL,
    OwnerName          VARCHAR(150) NULL,
    ComplaintNo        VARCHAR(50)  NULL,
    Details            VARCHAR(500) NULL,
    Status             VARCHAR(20)  NOT NULL DEFAULT 'Stolen',   -- Stolen / Recovered
    ReportedByBadgeID  VARCHAR(20)  NULL,
    ReportedAt         DATETIME     NOT NULL DEFAULT GETDATE(),
    RecoveredAt        DATETIME     NULL,
    RecoveredByBadgeID VARCHAR(20)  NULL
);
GO

SELECT * FROM StolenVehicles;
