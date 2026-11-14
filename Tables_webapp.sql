use Smart_traffic_System;

CREATE TABLE Officers (
    BadgeID VARCHAR(20) PRIMARY KEY,
    FullName VARCHAR(150) NOT NULL,
    NICNo VARCHAR(20) UNIQUE NOT NULL,
    Division VARCHAR(100) NOT NULL,
    PasswordHash VARCHAR(255) NOT NULL,
    CreatedAt DATETIME DEFAULT GETDATE()
);

CREATE TABLE Drivers (
    DriverID VARCHAR(30) PRIMARY KEY, -- License Number or NIC
    FullName VARCHAR(150) NOT NULL,
    DemeritPoints INT DEFAULT 0,
    RiskStatus VARCHAR(50) DEFAULT 'NORMAL', -- e.g., HIGH RISK, NORMAL
    CreatedAt DATETIME DEFAULT GETDATE()
);

CREATE TABLE Vehicles (
    RegistrationPlate VARCHAR(20) PRIMARY KEY,
    MakeAndModel VARCHAR(100) NOT NULL,
    RegisteredOwner VARCHAR(150) NOT NULL,
    RevenueLicenseStatus VARCHAR(50) NOT NULL, -- e.g., Valid, Expired
    InsuranceStatus VARCHAR(50) NOT NULL,
    PendingFineBalance DECIMAL(10, 2) DEFAULT 0.00
);

CREATE TABLE Violations (
    ViolationID INT IDENTITY(1,1) PRIMARY KEY,
    DriverID VARCHAR(30) FOREIGN KEY REFERENCES Drivers(DriverID),
    RegistrationPlate VARCHAR(20) FOREIGN KEY REFERENCES Vehicles(RegistrationPlate),
    ViolationType VARCHAR(100) NOT NULL,
    DemeritPointsAdded INT NOT NULL,
    RecordedLocation VARCHAR(255) NOT NULL,
    WitnessOfficerBadgeID VARCHAR(20) FOREIGN KEY REFERENCES Officers(BadgeID),
    OfficerRemarks TEXT,
    FineStatus VARCHAR(50) DEFAULT 'Unpaid', -- Unpaid, Settled
    ViolationDate DATETIME DEFAULT GETDATE()
);


