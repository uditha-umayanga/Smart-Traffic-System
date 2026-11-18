/* ==========================================================================
   TRAFFIX CENTRAL - COMPLETE sample data (single file)
   Run once in SSMS on your existing Smart_traffic_System database.

   - Creates tables only if missing; existing tables/data are never dropped.
   - Adds 4 officers, 32 licence numbers, 33 vehicles and ~190 violations
     (over-speeding, red light, lane departure, seatbelt, DUI).
   - Safe to run more than once (no duplicates).
   - New violations added from the Add Violation page save to the same tables
     and show in Driver Check as normal.

   Officer logins (password for all: 1234)
     POL-90145, POL-90146, POL-90147, POL-90148

   Test licences
     B2345678 / B9100141 : 23 pts (one violation away from suspension)
     B5678901            : clean record
     B3456789, B9100148, B9100155, B9100162 : HIGH RISK
   ========================================================================== */
IF DB_ID('Smart_traffic_System') IS NULL
    CREATE DATABASE Smart_traffic_System;
GO

USE Smart_traffic_System;
GO

/* ---------- Create tables only if they are missing ---------- */
IF OBJECT_ID('dbo.Officers', 'U') IS NULL
CREATE TABLE Officers (
    BadgeID      VARCHAR(20)  PRIMARY KEY,
    FullName     VARCHAR(150) NOT NULL,
    NICNo        VARCHAR(20)  UNIQUE NOT NULL,
    Division     VARCHAR(100) NOT NULL,
    PasswordHash VARCHAR(255) NOT NULL,
    CreatedAt    DATETIME     DEFAULT GETDATE()
);
GO

IF OBJECT_ID('dbo.Drivers', 'U') IS NULL
CREATE TABLE Drivers (
    DriverID      VARCHAR(30)  PRIMARY KEY,
    FullName      VARCHAR(150) NOT NULL,
    DemeritPoints INT          DEFAULT 0,
    RiskStatus    VARCHAR(50)  DEFAULT 'NORMAL',
    CreatedAt     DATETIME     DEFAULT GETDATE()
);
GO

IF OBJECT_ID('dbo.Vehicles', 'U') IS NULL
CREATE TABLE Vehicles (
    RegistrationPlate    VARCHAR(20)   PRIMARY KEY,
    MakeAndModel         VARCHAR(100)  NOT NULL,
    RegisteredOwner      VARCHAR(150)  NOT NULL,
    RevenueLicenseStatus VARCHAR(50)   NOT NULL,
    InsuranceStatus      VARCHAR(50)   NOT NULL,
    PendingFineBalance   DECIMAL(10,2) DEFAULT 0.00
);
GO

IF OBJECT_ID('dbo.Violations', 'U') IS NULL
CREATE TABLE Violations (
    ViolationID           INT IDENTITY(1,1) PRIMARY KEY,
    DriverID              VARCHAR(30)  FOREIGN KEY REFERENCES Drivers(DriverID),
    RegistrationPlate     VARCHAR(20)  FOREIGN KEY REFERENCES Vehicles(RegistrationPlate),
    ViolationType         VARCHAR(100) NOT NULL,
    DemeritPointsAdded    INT          NOT NULL,
    RecordedLocation      VARCHAR(255) NOT NULL,
    WitnessOfficerBadgeID VARCHAR(20)  FOREIGN KEY REFERENCES Officers(BadgeID),
    OfficerRemarks        TEXT,
    FineStatus            VARCHAR(50)  DEFAULT 'Unpaid',
    ViolationDate         DATETIME     DEFAULT GETDATE()
);
GO

/* ==========================================================================
   1. OFFICERS  (password = 1234, bcrypt hashed - same format the app uses)
   ========================================================================== */
INSERT INTO Officers (BadgeID, FullName, NICNo, Division, PasswordHash)
SELECT v.BadgeID, v.FullName, v.NICNo, v.Division, v.PasswordHash
FROM (VALUES
    ('POL-90145', 'SI R. M. Dissanayake', '199512403892', 'Colombo Central Traffic Division',   '$2a$10$LY8RWkia7U7f..jUfyPA8O/raFuRlPZ5N8CYzxyQ9IJgxfjWap6Gm'),
    ('POL-90146', 'PC K. A. Perera',      '199834501287', 'Colombo Central Traffic Division',   '$2a$10$LY8RWkia7U7f..jUfyPA8O/raFuRlPZ5N8CYzxyQ9IJgxfjWap6Gm'),
    ('POL-90147', 'IP S. Wijesinghe',     '198723401765', 'Southern Expressway Patrol Unit',    '$2a$10$LY8RWkia7U7f..jUfyPA8O/raFuRlPZ5N8CYzxyQ9IJgxfjWap6Gm'),
    ('POL-90148', 'SGT N. Fernando',      '199045602391', 'Kandy Traffic Division',             '$2a$10$LY8RWkia7U7f..jUfyPA8O/raFuRlPZ5N8CYzxyQ9IJgxfjWap6Gm')
) AS v (BadgeID, FullName, NICNo, Division, PasswordHash)
WHERE NOT EXISTS (SELECT 1 FROM Officers o WHERE o.BadgeID = v.BadgeID OR o.NICNo = v.NICNo);
GO

/* ==========================================================================
   2. DRIVERS  (points / risk status are calculated in section 5)
   ========================================================================== */
INSERT INTO Drivers (DriverID, FullName, DemeritPoints, RiskStatus)
SELECT v.DriverID, v.FullName, 0, 'NORMAL'
FROM (VALUES
    ('B1234567', 'Nimal Perera'),
    ('B2345678', 'Kasun Fernando'),
    ('B3456789', 'Sunil Jayawardena'),
    ('B4567890', 'Ishara Silva'),
    ('B5678901', 'Dilani Wickramasinghe'),
    ('B6789012', 'Ruwan Bandara'),
    ('B7890123', 'Tharindu Rajapaksa'),
    ('B8901234', 'Amaya Gunasekara')
) AS v (DriverID, FullName)
WHERE NOT EXISTS (SELECT 1 FROM Drivers d WHERE d.DriverID = v.DriverID);
GO

/* ==========================================================================
   3. VEHICLES
   ========================================================================== */
INSERT INTO Vehicles (RegistrationPlate, MakeAndModel, RegisteredOwner, RevenueLicenseStatus, InsuranceStatus, PendingFineBalance)
SELECT v.Plate, v.Model, v.Owner, v.Revenue, v.Insurance, 0
FROM (VALUES
    ('WP CAA-7892', 'Toyota Aqua',            'Nimal Perera',          'Valid',   'Valid'),
    ('WP KY-4521',  'Suzuki Alto',            'Kasun Fernando',        'Valid',   'Valid'),
    ('SP GA-1234',  'Honda Vezel',            'Sunil Jayawardena',     'Expired', 'Valid'),
    ('CP BDF-5566', 'Nissan Leaf',            'Ishara Silva',          'Valid',   'Expired'),
    ('WP BHG-9087', 'Toyota Prius',           'Dilani Wickramasinghe', 'Valid',   'Valid'),
    ('NW LA-3344',  'Mitsubishi Montero',     'Ruwan Bandara',         'Valid',   'Valid'),
    ('WP CBN-7721', 'Toyota Hilux',           'Tharindu Rajapaksa',    'Expired', 'Expired'),
    ('SG PH-2210',  'Honda Fit',              'Amaya Gunasekara',      'Valid',   'Valid'),
    ('WP CAB-1010', 'Micro Panda',            'Dilani Wickramasinghe', 'Valid',   'Valid')
) AS v (Plate, Model, Owner, Revenue, Insurance)
WHERE NOT EXISTS (SELECT 1 FROM Vehicles x WHERE x.RegistrationPlate = v.Plate);
GO

/* ==========================================================================
   4 + 5. VIOLATIONS, then recalculate driver points and vehicle fine balance
   ViolationType values match the app: speeding, red_light, lane_departure, dui, belt
   Points: speeding 4 | red_light 3 | lane_departure 3 | dui 10 | belt 2
   Skipped automatically if the sample drivers already have violations.
   ========================================================================== */
IF NOT EXISTS (SELECT 1 FROM Violations
               WHERE DriverID IN ('B1234567','B2345678','B3456789','B4567890',
                                  'B5678901','B6789012','B7890123','B8901234'))
BEGIN
    INSERT INTO Violations (DriverID, RegistrationPlate, ViolationType, DemeritPointsAdded,
                            RecordedLocation, WitnessOfficerBadgeID, OfficerRemarks, FineStatus, ViolationDate)
    VALUES
    -- Nimal Perera: 9 points
    ('B1234567', 'WP CAA-7892', 'speeding',       4, 'Galle Road, Bambalapitiya, Colombo 04',  'POL-90146', 'Radar reading 78 km/h in a 50 km/h zone. Ref RD-2231.',        'Settled', DATEADD(DAY, -120, GETDATE())),
    ('B1234567', 'WP CAA-7892', 'red_light',      3, 'Union Place Junction, Colombo 02',       'POL-90146', 'Crossed on red. Camera evidence CAM-0457.',                    'Settled', DATEADD(DAY,  -60, GETDATE())),
    ('B1234567', 'WP CAA-7892', 'belt',           2, 'High Level Road, Nugegoda',              'POL-90147', 'Driver not wearing seatbelt.',                                 'Unpaid',  DATEADD(DAY,  -12, GETDATE())),

    -- Kasun Fernando: 23 points (one point below suspension - good for testing)
    ('B2345678', 'WP KY-4521',  'speeding',       4, 'Baseline Road, Borella',                 'POL-90146', 'Radar reading 85 km/h. Ref RD-1980.',                          'Settled', DATEADD(DAY, -300, GETDATE())),
    ('B2345678', 'WP KY-4521',  'speeding',       4, 'Kandy Road, Kiribathgoda',               'POL-90147', 'Radar reading 92 km/h. Ref RD-2044.',                          'Settled', DATEADD(DAY, -240, GETDATE())),
    ('B2345678', 'WP KY-4521',  'red_light',      3, 'Pettah Junction, Colombo 11',            'POL-90146', 'Ran red light. Camera ref CAM-0301.',                          'Settled', DATEADD(DAY, -180, GETDATE())),
    ('B2345678', 'WP KY-4521',  'lane_departure', 3, 'Colombo-Katunayake Expressway',          'POL-90147', 'Drifted across lanes without signalling.',                     'Settled', DATEADD(DAY, -120, GETDATE())),
    ('B2345678', 'WP KY-4521',  'belt',           2, 'Duplication Road, Colombo 03',           'POL-90145', 'No seatbelt.',                                                 'Settled', DATEADD(DAY,  -75, GETDATE())),
    ('B2345678', 'WP KY-4521',  'red_light',      3, 'Thimbirigasyaya Junction, Colombo 05',   'POL-90146', 'Ran red light. Camera ref CAM-0512.',                          'Unpaid',  DATEADD(DAY,  -30, GETDATE())),
    ('B2345678', 'WP KY-4521',  'speeding',       4, 'Parliament Road, Battaramulla',          'POL-90145', 'Radar reading 81 km/h in 60 km/h zone. Ref RD-2301.',          'Unpaid',  DATEADD(DAY,   -9, GETDATE())),

    -- Sunil Jayawardena: 24 points -> HIGH RISK / suspended
    ('B3456789', 'SP GA-1234',  'dui',           10, 'Galle Face Green, Colombo 01',           'POL-90145', 'Breathalyser positive. Vehicle impounded. Ref BA-0087.',       'Unpaid',  DATEADD(DAY, -200, GETDATE())),
    ('B3456789', 'SP GA-1234',  'speeding',       4, 'Southern Expressway, Kahathuduwa',       'POL-90148', 'Radar reading 130 km/h. Ref RD-1765.',                         'Settled', DATEADD(DAY, -150, GETDATE())),
    ('B3456789', 'SP GA-1234',  'speeding',       4, 'Southern Expressway, Pinnaduwa',         'POL-90148', 'Radar reading 125 km/h. Ref RD-1799.',                         'Unpaid',  DATEADD(DAY,  -90, GETDATE())),
    ('B3456789', 'SP GA-1234',  'red_light',      3, 'Galle Fort Junction, Galle',             'POL-90146', 'Ran red light.',                                               'Unpaid',  DATEADD(DAY,  -45, GETDATE())),
    ('B3456789', 'SP GA-1234',  'lane_departure', 3, 'Matara Road, Weligama',                  'POL-90146', 'Reckless overtaking across solid line.',                       'Unpaid',  DATEADD(DAY,  -20, GETDATE())),

    -- Ishara Silva: 2 points
    ('B4567890', 'CP BDF-5566', 'belt',           2, 'Peradeniya Road, Kandy',                 'POL-90148', 'No seatbelt on front passenger and driver.',                   'Settled', DATEADD(DAY,  -50, GETDATE())),

    -- Dilani Wickramasinghe: clean record (no violations)

    -- Ruwan Bandara: 11 points
    ('B6789012', 'NW LA-3344',  'red_light',      3, 'Clock Tower Junction, Kurunegala',       'POL-90146', 'Ran red light. Camera ref CAM-0620.',                          'Settled', DATEADD(DAY, -100, GETDATE())),
    ('B6789012', 'NW LA-3344',  'lane_departure', 3, 'Kurunegala-Dambulla Road',               'POL-90147', 'Lane drift, near collision with oncoming bus.',                'Settled', DATEADD(DAY,  -70, GETDATE())),
    ('B6789012', 'NW LA-3344',  'red_light',      3, 'Wariyapola Junction',                    'POL-90147', 'Ran red light.',                                               'Unpaid',  DATEADD(DAY,  -25, GETDATE())),
    ('B6789012', 'NW LA-3344',  'belt',           2, 'Puttalam Road, Kurunegala',              'POL-90145', 'No seatbelt.',                                                 'Unpaid',  DATEADD(DAY,   -5, GETDATE())),

    -- Tharindu Rajapaksa: 17 points
    ('B7890123', 'WP CBN-7721', 'dui',           10, 'Marine Drive, Wellawatte',               'POL-90145', 'Breathalyser positive. Ref BA-0102.',                          'Unpaid',  DATEADD(DAY,  -80, GETDATE())),
    ('B7890123', 'WP CBN-7721', 'speeding',       4, 'Baseline Road, Dematagoda',              'POL-90146', 'Radar reading 88 km/h. Ref RD-2150.',                          'Unpaid',  DATEADD(DAY,  -40, GETDATE())),
    ('B7890123', 'WP CBN-7721', 'lane_departure', 3, 'Rajagiriya Flyover',                     'POL-90146', 'Unsafe lane change on flyover.',                               'Unpaid',  DATEADD(DAY,  -14, GETDATE())),

    -- Amaya Gunasekara: 6 points
    ('B8901234', 'SG PH-2210',  'speeding',       4, 'Kandy Road, Peradeniya',                 'POL-90148', 'Radar reading 75 km/h in 50 km/h zone. Ref RD-2288.',          'Settled', DATEADD(DAY,  -35, GETDATE())),
    ('B8901234', 'SG PH-2210',  'belt',           2, 'Hill Street, Kandy',                     'POL-90148', 'No seatbelt.',                                                 'Unpaid',  DATEADD(DAY,   -3, GETDATE()));

    -- Recalculate each driver's points and risk status from the violations above
    UPDATE d
    SET DemeritPoints = ISNULL(s.TotalPoints, 0),
        RiskStatus    = CASE WHEN ISNULL(s.TotalPoints, 0) >= 24 THEN 'HIGH RISK' ELSE 'NORMAL' END
    FROM Drivers d
    LEFT JOIN (SELECT DriverID, SUM(DemeritPointsAdded) AS TotalPoints
               FROM Violations GROUP BY DriverID) s ON s.DriverID = d.DriverID
    WHERE d.DriverID IN ('B1234567','B2345678','B3456789','B4567890',
                         'B5678901','B6789012','B7890123','B8901234');

    -- Vehicle pending fine balance (LKR) = sum of unpaid fines
    -- Fine amounts: speeding 2500 | red_light 2500 | lane_departure 2000 | dui 25000 | belt 1000
    UPDATE v
    SET PendingFineBalance = ISNULL(f.Total, 0)
    FROM Vehicles v
    LEFT JOIN (SELECT RegistrationPlate,
                      SUM(CASE ViolationType
                              WHEN 'speeding'       THEN 2500
                              WHEN 'red_light'      THEN 2500
                              WHEN 'lane_departure' THEN 2000
                              WHEN 'dui'            THEN 25000
                              WHEN 'belt'           THEN 1000
                              ELSE 0 END) AS Total
               FROM Violations
               WHERE FineStatus = 'Unpaid'
               GROUP BY RegistrationPlate) f ON f.RegistrationPlate = v.RegistrationPlate;
END
GO


/* ---------- Extra licence numbers ---------- */
USE Smart_traffic_System;
GO

INSERT INTO Drivers (DriverID, FullName, DemeritPoints, RiskStatus)
SELECT v.DriverID, v.FullName, 0, 'NORMAL'
FROM (VALUES
    ('B9100001', 'Chamara Silva'),
    ('B9100008', 'Priyanka Jayasinghe'),
    ('B9100015', 'Lasith Malinga Perera'),
    ('B9100022', 'Nadeesha Weerasinghe'),
    ('B9100029', 'Saman Kumara'),
    ('B9100036', 'Hiruni Senanayake'),
    ('B9100043', 'Dinesh Gamage'),
    ('B9100050', 'Thilini Abeysekara'),
    ('B9100057', 'Pradeep Madushanka'),
    ('B9100064', 'Sachini Ratnayake'),
    ('B9100071', 'Roshan De Silva'),
    ('B9100078', 'Anusha Herath'),
    ('B9100085', 'Lakmal Dias'),
    ('B9100092', 'Kavindi Samarasinghe'),
    ('B9100099', 'Mahesh Karunaratne'),
    ('B9100106', 'Shanika Liyanage'),
    ('B9100113', 'Asanka Pathirana'),
    ('B9100120', 'Dulani Amarasinghe'),
    ('B9100127', 'Chathura Rodrigo'),
    ('B9100134', 'Nirmala Jayawardena'),
    ('B9100141', 'Upul Tennakoon'),
    ('B9100148', 'Madhavi Ekanayake'),
    ('B9100155', 'Janaka Ranasinghe'),
    ('B9100162', 'Ayesha Marikar')
) AS v (DriverID, FullName)
WHERE NOT EXISTS (SELECT 1 FROM Drivers d WHERE d.DriverID = v.DriverID);
GO

INSERT INTO Vehicles (RegistrationPlate, MakeAndModel, RegisteredOwner, RevenueLicenseStatus, InsuranceStatus, PendingFineBalance)
SELECT v.Plate, v.Model, v.Owner, v.Revenue, v.Insurance, 0
FROM (VALUES
    ('WP CAD-2824', 'Toyota Vitz', 'Chamara Silva', 'Valid', 'Valid'),
    ('WP KR-5012', 'Suzuki Wagon R', 'Priyanka Jayasinghe', 'Valid', 'Valid'),
    ('CP KA-4257', 'Honda Civic', 'Lasith Malinga Perera', 'Expired', 'Valid'),
    ('SP GB-6514', 'Nissan Sunny', 'Nadeesha Weerasinghe', 'Valid', 'Valid'),
    ('NW LB-4150', 'Toyota Axio', 'Saman Kumara', 'Valid', 'Valid'),
    ('WP BEE-4598', 'Suzuki Swift', 'Hiruni Senanayake', 'Valid', 'Valid'),
    ('SG PB-3266', 'Hyundai Elantra', 'Dinesh Gamage', 'Expired', 'Valid'),
    ('NC KA-6573', 'Kia Picanto', 'Thilini Abeysekara', 'Valid', 'Valid'),
    ('UP PA-2832', 'Toyota Corolla', 'Pradeep Madushanka', 'Valid', 'Valid'),
    ('WP CBA-4981', 'Mazda Demio', 'Sachini Ratnayake', 'Expired', 'Expired'),
    ('EP KB-8886', 'Mitsubishi Lancer', 'Roshan De Silva', 'Valid', 'Expired'),
    ('WP KT-4910', 'Toyota Premio', 'Anusha Herath', 'Valid', 'Expired'),
    ('CP BCC-7267', 'Suzuki Alto', 'Lakmal Dias', 'Valid', 'Expired'),
    ('SP GC-6344', 'Nissan X-Trail', 'Kavindi Samarasinghe', 'Expired', 'Valid'),
    ('WP CAF-7790', 'Toyota CHR', 'Mahesh Karunaratne', 'Valid', 'Expired'),
    ('NW KV-3267', 'Honda Grace', 'Shanika Liyanage', 'Valid', 'Valid'),
    ('WP BJA-8956', 'Bajaj Three-Wheeler', 'Asanka Pathirana', 'Valid', 'Expired'),
    ('CP KB-1207', 'Tata Nano', 'Dulani Amarasinghe', 'Expired', 'Expired'),
    ('SP GD-7625', 'Toyota Land Cruiser', 'Chathura Rodrigo', 'Valid', 'Valid'),
    ('WP CBG-8699', 'Isuzu D-Max', 'Nirmala Jayawardena', 'Valid', 'Valid'),
    ('SG PC-2899', 'Micro Kuv', 'Upul Tennakoon', 'Expired', 'Valid'),
    ('WP KZ-3434', 'Ford Ranger', 'Madhavi Ekanayake', 'Expired', 'Expired'),
    ('NW LC-1753', 'Daihatsu Mira', 'Janaka Ranasinghe', 'Valid', 'Valid'),
    ('WP BKK-3531', 'BMW 320i', 'Ayesha Marikar', 'Expired', 'Valid'),
    ('WP CAZ-1001', 'Toyota Aqua', 'Chamara Silva', 'Valid', 'Valid'),
    ('CP KC-2002', 'Honda Vezel', 'Hiruni Senanayake', 'Valid', 'Valid'),
    ('SP GE-3003', 'Suzuki Alto', 'Roshan De Silva', 'Valid', 'Valid')
) AS v (Plate, Model, Owner, Revenue, Insurance)
WHERE NOT EXISTS (SELECT 1 FROM Vehicles x WHERE x.RegistrationPlate = v.Plate);
GO

IF NOT EXISTS (SELECT 1 FROM Violations WHERE DriverID IN ('B9100001','B9100008','B9100015','B9100022','B9100029','B9100036','B9100043','B9100050','B9100057','B9100064','B9100071','B9100078','B9100085','B9100092','B9100099','B9100106','B9100113','B9100120','B9100127','B9100134','B9100141','B9100148','B9100155','B9100162'))
BEGIN
    INSERT INTO Violations (DriverID, RegistrationPlate, ViolationType, DemeritPointsAdded,
                            RecordedLocation, WitnessOfficerBadgeID, OfficerRemarks, FineStatus, ViolationDate)
    VALUES
    ('B9100008', 'WP KR-5012', 'belt', 2, 'Outer Circular Highway, Kaduwela', 'POL-90145', 'Driver not wearing seatbelt.', 'Settled', DATEADD(DAY, -194, GETDATE())),
    ('B9100015', 'CP KA-4257', 'lane_departure', 3, 'Baseline Road, Maradana', 'POL-90146', 'Reckless lane drift without signalling.', 'Settled', DATEADD(DAY, -192, GETDATE())),
    ('B9100022', 'SP GB-6514', 'speeding', 4, 'Panadura Junction', 'POL-90147', 'Speed gun reading 80 km/h. Ref RD-1600.', 'Settled', DATEADD(DAY, -206, GETDATE())),
    ('B9100029', 'NW LB-4150', 'belt', 2, 'Southern Expressway, Gelanigama', 'POL-90147', 'No seatbelt / helmet worn.', 'Settled', DATEADD(DAY, -266, GETDATE())),
    ('B9100029', 'NW LB-4150', 'lane_departure', 3, 'Sri Jayawardenepura Mawatha, Kotte', 'POL-90147', 'Reckless lane drift without signalling.', 'Unpaid', DATEADD(DAY, -134, GETDATE())),
    ('B9100036', 'WP BEE-4598', 'belt', 2, 'Baseline Road, Maradana', 'POL-90147', 'No seatbelt / helmet worn.', 'Settled', DATEADD(DAY, -262, GETDATE())),
    ('B9100036', 'WP BEE-4598', 'speeding', 4, 'Nawala Road, Rajagiriya', 'POL-90146', 'Speed gun reading 124 km/h. Ref RD-1817.', 'Settled', DATEADD(DAY, -136, GETDATE())),
    ('B9100043', 'SG PB-3266', 'red_light', 3, 'Borella Junction, Colombo 08', 'POL-90148', 'Ran red light, witnessed by patrol unit.', 'Settled', DATEADD(DAY, -257, GETDATE())),
    ('B9100043', 'SG PB-3266', 'speeding', 4, 'Horana Road, Kottawa', 'POL-90147', 'Radar reading 84 km/h in a 70 km/h zone. Ref RD-2812.', 'Settled', DATEADD(DAY, -148, GETDATE())),
    ('B9100050', 'NC KA-6573', 'speeding', 4, 'Borella Junction, Colombo 08', 'POL-90146', 'Radar reading 108 km/h in a 70 km/h zone. Ref RD-2039.', 'Unpaid', DATEADD(DAY, -260, GETDATE())),
    ('B9100050', 'NC KA-6573', 'speeding', 4, 'Matara Road, Galle', 'POL-90145', 'Radar reading 70 km/h in a 70 km/h zone. Ref RD-1663.', 'Unpaid', DATEADD(DAY, -136, GETDATE())),
    ('B9100057', 'UP PA-2832', 'belt', 2, 'Negombo Road, Wattala', 'POL-90148', 'No seatbelt / helmet worn.', 'Settled', DATEADD(DAY, -306, GETDATE())),
    ('B9100057', 'UP PA-2832', 'belt', 2, 'Horana Road, Kottawa', 'POL-90146', 'Driver not wearing seatbelt.', 'Settled', DATEADD(DAY, -231, GETDATE())),
    ('B9100057', 'UP PA-2832', 'belt', 2, 'High Level Road, Maharagama', 'POL-90147', 'Driver not wearing seatbelt.', 'Settled', DATEADD(DAY, -163, GETDATE())),
    ('B9100057', 'UP PA-2832', 'red_light', 3, 'Baseline Road, Maradana', 'POL-90148', 'Ran red light, witnessed by patrol unit.', 'Unpaid', DATEADD(DAY, -86, GETDATE())),
    ('B9100064', 'WP CBA-4981', 'speeding', 4, 'Baseline Road, Maradana', 'POL-90148', 'Radar reading 94 km/h in a 70 km/h zone. Ref RD-1918.', 'Settled', DATEADD(DAY, -292, GETDATE())),
    ('B9100064', 'WP CBA-4981', 'speeding', 4, 'Horana Road, Kottawa', 'POL-90145', 'Radar reading 79 km/h in a 60 km/h zone. Ref RD-2654.', 'Settled', DATEADD(DAY, -197, GETDATE())),
    ('B9100064', 'WP CBA-4981', 'belt', 2, 'Peradeniya Road, Kandy', 'POL-90148', 'Driver not wearing seatbelt.', 'Unpaid', DATEADD(DAY, -103, GETDATE())),
    ('B9100071', 'EP KB-8886', 'lane_departure', 3, 'Southern Expressway, Kottawa', 'POL-90145', 'Reckless lane drift without signalling.', 'Settled', DATEADD(DAY, -297, GETDATE())),
    ('B9100071', 'EP KB-8886', 'speeding', 4, 'Kollupitiya Junction, Colombo 03', 'POL-90146', 'Radar reading 121 km/h in a 50 km/h zone. Ref RD-2928.', 'Settled', DATEADD(DAY, -194, GETDATE())),
    ('B9100071', 'EP KB-8886', 'speeding', 4, 'Moratuwa Junction', 'POL-90147', 'Speed gun reading 110 km/h. Ref RD-1418.', 'Unpaid', DATEADD(DAY, -103, GETDATE())),
    ('B9100078', 'WP KT-4910', 'belt', 2, 'Horana Road, Kottawa', 'POL-90146', 'Driver not wearing seatbelt.', 'Settled', DATEADD(DAY, -312, GETDATE())),
    ('B9100078', 'WP KT-4910', 'belt', 2, 'Nawala Road, Rajagiriya', 'POL-90146', 'No seatbelt / helmet worn.', 'Settled', DATEADD(DAY, -265, GETDATE())),
    ('B9100078', 'WP KT-4910', 'speeding', 4, 'Baseline Road, Maradana', 'POL-90146', 'Speed gun reading 122 km/h. Ref RD-2534.', 'Settled', DATEADD(DAY, -199, GETDATE())),
    ('B9100078', 'WP KT-4910', 'belt', 2, 'Jaffna-Kandy Road, Vavuniya', 'POL-90147', 'Driver not wearing seatbelt.', 'Unpaid', DATEADD(DAY, -137, GETDATE())),
    ('B9100078', 'WP KT-4910', 'belt', 2, 'Anuradhapura Road, Kekirawa', 'POL-90145', 'Driver not wearing seatbelt.', 'Unpaid', DATEADD(DAY, -85, GETDATE())),
    ('B9100085', 'CP BCC-7267', 'speeding', 4, 'Peradeniya Road, Kandy', 'POL-90147', 'Speed gun reading 74 km/h. Ref RD-2221.', 'Settled', DATEADD(DAY, -303, GETDATE())),
    ('B9100085', 'CP BCC-7267', 'belt', 2, 'Colombo-Katunayake Expressway, Ja-Ela', 'POL-90145', 'Driver not wearing seatbelt.', 'Settled', DATEADD(DAY, -238, GETDATE())),
    ('B9100085', 'CP BCC-7267', 'lane_departure', 3, 'Moratuwa Junction', 'POL-90147', 'Reckless lane drift without signalling.', 'Settled', DATEADD(DAY, -169, GETDATE())),
    ('B9100085', 'CP BCC-7267', 'speeding', 4, 'Moratuwa Junction', 'POL-90148', 'Radar reading 108 km/h in a 70 km/h zone. Ref RD-1633.', 'Unpaid', DATEADD(DAY, -94, GETDATE())),
    ('B9100092', 'SP GC-6344', 'dui', 10, 'Jaffna-Kandy Road, Vavuniya', 'POL-90146', 'DUI suspected, breath test failed. Ref BA-1969.', 'Settled', DATEADD(DAY, -292, GETDATE())),
    ('B9100092', 'SP GC-6344', 'belt', 2, 'Duplication Road, Kollupitiya', 'POL-90146', 'No seatbelt / helmet worn.', 'Settled', DATEADD(DAY, -194, GETDATE())),
    ('B9100092', 'SP GC-6344', 'belt', 2, 'Colombo-Kandy Road, Kadawatha', 'POL-90148', 'Driver not wearing seatbelt.', 'Settled', DATEADD(DAY, -108, GETDATE())),
    ('B9100099', 'WP CAF-7790', 'red_light', 3, 'Matara Road, Galle', 'POL-90148', 'Ran red light, witnessed by patrol unit.', 'Unpaid', DATEADD(DAY, -292, GETDATE())),
    ('B9100099', 'WP CAF-7790', 'dui', 10, 'Colombo-Katunayake Expressway, Ja-Ela', 'POL-90148', 'DUI suspected, breath test failed. Ref BA-1489.', 'Settled', DATEADD(DAY, -200, GETDATE())),
    ('B9100099', 'WP CAF-7790', 'belt', 2, 'Horana Road, Kottawa', 'POL-90145', 'Driver not wearing seatbelt.', 'Unpaid', DATEADD(DAY, -104, GETDATE())),
    ('B9100106', 'NW KV-3267', 'dui', 10, 'Southern Expressway, Gelanigama', 'POL-90148', 'DUI suspected, breath test failed. Ref BA-1127.', 'Settled', DATEADD(DAY, -284, GETDATE())),
    ('B9100106', 'NW KV-3267', 'red_light', 3, 'Nawala Road, Rajagiriya', 'POL-90147', 'Crossed on red signal. Camera ref CAM-1012.', 'Unpaid', DATEADD(DAY, -204, GETDATE())),
    ('B9100106', 'NW KV-3267', 'red_light', 3, 'Colombo-Katunayake Expressway, Ja-Ela', 'POL-90148', 'Ran red light, witnessed by patrol unit.', 'Unpaid', DATEADD(DAY, -114, GETDATE())),
    ('B9100113', 'WP BJA-8956', 'lane_departure', 3, 'Matara Road, Galle', 'POL-90145', 'Reckless lane drift without signalling.', 'Settled', DATEADD(DAY, -319, GETDATE())),
    ('B9100113', 'WP BJA-8956', 'red_light', 3, 'Borella Junction, Colombo 08', 'POL-90145', 'Ran red light, witnessed by patrol unit.', 'Settled', DATEADD(DAY, -258, GETDATE())),
    ('B9100113', 'WP BJA-8956', 'speeding', 4, 'Sri Jayawardenepura Mawatha, Kotte', 'POL-90148', 'Radar reading 109 km/h in a 70 km/h zone. Ref RD-2387.', 'Settled', DATEADD(DAY, -197, GETDATE())),
    ('B9100113', 'WP BJA-8956', 'speeding', 4, 'Duplication Road, Kollupitiya', 'POL-90145', 'Radar reading 83 km/h in a 70 km/h zone. Ref RD-2582.', 'Settled', DATEADD(DAY, -138, GETDATE())),
    ('B9100113', 'WP BJA-8956', 'speeding', 4, 'Panadura Junction', 'POL-90147', 'Speed gun reading 117 km/h. Ref RD-2036.', 'Unpaid', DATEADD(DAY, -73, GETDATE())),
    ('B9100120', 'CP KB-1207', 'speeding', 4, 'Havelock Road, Colombo 05', 'POL-90146', 'Speed gun reading 113 km/h. Ref RD-2012.', 'Settled', DATEADD(DAY, -314, GETDATE())),
    ('B9100120', 'CP KB-1207', 'lane_departure', 3, 'Borella Junction, Colombo 08', 'POL-90147', 'Unsafe overtaking across solid line.', 'Settled', DATEADD(DAY, -243, GETDATE())),
    ('B9100120', 'CP KB-1207', 'dui', 10, 'Peradeniya Road, Kandy', 'POL-90148', 'Breathalyser positive. Ref BA-2474.', 'Settled', DATEADD(DAY, -156, GETDATE())),
    ('B9100120', 'CP KB-1207', 'red_light', 3, 'Duplication Road, Kollupitiya', 'POL-90146', 'Ran red light, witnessed by patrol unit.', 'Unpaid', DATEADD(DAY, -91, GETDATE())),
    ('B9100127', 'SP GD-7625', 'red_light', 3, 'Baseline Road, Maradana', 'POL-90148', 'Crossed on red signal. Camera ref CAM-2933.', 'Settled', DATEADD(DAY, -335, GETDATE())),
    ('B9100127', 'SP GD-7625', 'lane_departure', 3, 'Southern Expressway, Kottawa', 'POL-90145', 'Unsafe overtaking across solid line.', 'Unpaid', DATEADD(DAY, -285, GETDATE())),
    ('B9100127', 'SP GD-7625', 'red_light', 3, 'Kollupitiya Junction, Colombo 03', 'POL-90145', 'Crossed on red signal. Camera ref CAM-1151.', 'Unpaid', DATEADD(DAY, -245, GETDATE())),
    ('B9100127', 'SP GD-7625', 'lane_departure', 3, 'Horana Road, Kottawa', 'POL-90148', 'Unsafe overtaking across solid line.', 'Settled', DATEADD(DAY, -196, GETDATE())),
    ('B9100127', 'SP GD-7625', 'speeding', 4, 'Kollupitiya Junction, Colombo 03', 'POL-90148', 'Speed gun reading 127 km/h. Ref RD-1608.', 'Settled', DATEADD(DAY, -154, GETDATE())),
    ('B9100127', 'SP GD-7625', 'belt', 2, 'Southern Expressway, Gelanigama', 'POL-90147', 'Driver not wearing seatbelt.', 'Unpaid', DATEADD(DAY, -111, GETDATE())),
    ('B9100127', 'SP GD-7625', 'red_light', 3, 'Peradeniya Road, Kandy', 'POL-90148', 'Crossed on red signal. Camera ref CAM-1005.', 'Settled', DATEADD(DAY, -59, GETDATE())),
    ('B9100134', 'WP CBG-8699', 'belt', 2, 'Anuradhapura Road, Kekirawa', 'POL-90147', 'No seatbelt / helmet worn.', 'Settled', DATEADD(DAY, -332, GETDATE())),
    ('B9100134', 'WP CBG-8699', 'red_light', 3, 'High Level Road, Maharagama', 'POL-90148', 'Ran red light, witnessed by patrol unit.', 'Unpaid', DATEADD(DAY, -294, GETDATE())),
    ('B9100134', 'WP CBG-8699', 'red_light', 3, 'Moratuwa Junction', 'POL-90145', 'Crossed on red signal. Camera ref CAM-2969.', 'Settled', DATEADD(DAY, -247, GETDATE())),
    ('B9100134', 'WP CBG-8699', 'lane_departure', 3, 'Kurunegala-Dambulla Road', 'POL-90147', 'Reckless lane drift without signalling.', 'Settled', DATEADD(DAY, -200, GETDATE())),
    ('B9100134', 'WP CBG-8699', 'red_light', 3, 'Peradeniya Road, Kandy', 'POL-90147', 'Ran red light, witnessed by patrol unit.', 'Unpaid', DATEADD(DAY, -152, GETDATE())),
    ('B9100134', 'WP CBG-8699', 'speeding', 4, 'Matara Road, Galle', 'POL-90147', 'Radar reading 112 km/h in a 60 km/h zone. Ref RD-2420.', 'Unpaid', DATEADD(DAY, -112, GETDATE())),
    ('B9100134', 'WP CBG-8699', 'speeding', 4, 'Colombo-Katunayake Expressway, Ja-Ela', 'POL-90147', 'Radar reading 128 km/h in a 50 km/h zone. Ref RD-1644.', 'Unpaid', DATEADD(DAY, -69, GETDATE())),
    ('B9100141', 'SG PC-2899', 'dui', 10, 'Kandy Road, Peliyagoda', 'POL-90148', 'Breathalyser positive. Ref BA-1460.', 'Settled', DATEADD(DAY, -317, GETDATE())),
    ('B9100141', 'SG PC-2899', 'speeding', 4, 'Negombo Road, Wattala', 'POL-90147', 'Radar reading 133 km/h in a 70 km/h zone. Ref RD-1597.', 'Settled', DATEADD(DAY, -255, GETDATE())),
    ('B9100141', 'SG PC-2899', 'speeding', 4, 'Sri Jayawardenepura Mawatha, Kotte', 'POL-90146', 'Radar reading 128 km/h in a 70 km/h zone. Ref RD-1296.', 'Unpaid', DATEADD(DAY, -205, GETDATE())),
    ('B9100141', 'SG PC-2899', 'belt', 2, 'Peradeniya Road, Kandy', 'POL-90147', 'Driver not wearing seatbelt.', 'Unpaid', DATEADD(DAY, -148, GETDATE())),
    ('B9100141', 'SG PC-2899', 'red_light', 3, 'Kollupitiya Junction, Colombo 03', 'POL-90148', 'Crossed on red signal. Camera ref CAM-1611.', 'Settled', DATEADD(DAY, -88, GETDATE())),
    ('B9100148', 'WP KZ-3434', 'lane_departure', 3, 'Panadura Junction', 'POL-90146', 'Unsafe overtaking across solid line.', 'Settled', DATEADD(DAY, -333, GETDATE())),
    ('B9100148', 'WP KZ-3434', 'red_light', 3, 'Negombo Road, Wattala', 'POL-90148', 'Ran red light, witnessed by patrol unit.', 'Settled', DATEADD(DAY, -284, GETDATE())),
    ('B9100148', 'WP KZ-3434', 'red_light', 3, 'Colombo-Katunayake Expressway, Ja-Ela', 'POL-90147', 'Ran red light, witnessed by patrol unit.', 'Settled', DATEADD(DAY, -217, GETDATE())),
    ('B9100148', 'WP KZ-3434', 'belt', 2, 'Anuradhapura Road, Kekirawa', 'POL-90148', 'No seatbelt / helmet worn.', 'Settled', DATEADD(DAY, -178, GETDATE())),
    ('B9100148', 'WP KZ-3434', 'dui', 10, 'Colombo-Kandy Road, Kadawatha', 'POL-90148', 'Breathalyser positive. Ref BA-2529.', 'Unpaid', DATEADD(DAY, -115, GETDATE())),
    ('B9100148', 'WP KZ-3434', 'red_light', 3, 'Duplication Road, Kollupitiya', 'POL-90145', 'Crossed on red signal. Camera ref CAM-2421.', 'Unpaid', DATEADD(DAY, -66, GETDATE())),
    ('B9100155', 'NW LC-1753', 'red_light', 3, 'Jaffna-Kandy Road, Vavuniya', 'POL-90146', 'Ran red light, witnessed by patrol unit.', 'Settled', DATEADD(DAY, -337, GETDATE())),
    ('B9100155', 'NW LC-1753', 'belt', 2, 'Horana Road, Kottawa', 'POL-90147', 'No seatbelt / helmet worn.', 'Unpaid', DATEADD(DAY, -302, GETDATE())),
    ('B9100155', 'NW LC-1753', 'lane_departure', 3, 'Matara Road, Galle', 'POL-90147', 'Unsafe overtaking across solid line.', 'Settled', DATEADD(DAY, -280, GETDATE())),
    ('B9100155', 'NW LC-1753', 'red_light', 3, 'Moratuwa Junction', 'POL-90148', 'Crossed on red signal. Camera ref CAM-2761.', 'Unpaid', DATEADD(DAY, -238, GETDATE())),
    ('B9100155', 'NW LC-1753', 'red_light', 3, 'Kandy Road, Peliyagoda', 'POL-90148', 'Ran red light, witnessed by patrol unit.', 'Settled', DATEADD(DAY, -203, GETDATE())),
    ('B9100155', 'NW LC-1753', 'belt', 2, 'Nawala Road, Rajagiriya', 'POL-90145', 'No seatbelt / helmet worn.', 'Settled', DATEADD(DAY, -167, GETDATE())),
    ('B9100155', 'NW LC-1753', 'lane_departure', 3, 'Panadura Junction', 'POL-90148', 'Unsafe overtaking across solid line.', 'Unpaid', DATEADD(DAY, -127, GETDATE())),
    ('B9100155', 'NW LC-1753', 'red_light', 3, 'High Level Road, Maharagama', 'POL-90147', 'Crossed on red signal. Camera ref CAM-2937.', 'Unpaid', DATEADD(DAY, -93, GETDATE())),
    ('B9100155', 'NW LC-1753', 'speeding', 4, 'Nawala Road, Rajagiriya', 'POL-90148', 'Radar reading 87 km/h in a 60 km/h zone. Ref RD-1929.', 'Settled', DATEADD(DAY, -63, GETDATE())),
    ('B9100162', 'WP BKK-3531', 'speeding', 4, 'Borella Junction, Colombo 08', 'POL-90145', 'Radar reading 112 km/h in a 50 km/h zone. Ref RD-2615.', 'Settled', DATEADD(DAY, -342, GETDATE())),
    ('B9100162', 'WP BKK-3531', 'speeding', 4, 'Moratuwa Junction', 'POL-90145', 'Radar reading 102 km/h in a 50 km/h zone. Ref RD-1225.', 'Settled', DATEADD(DAY, -308, GETDATE())),
    ('B9100162', 'WP BKK-3531', 'lane_departure', 3, 'Colombo-Katunayake Expressway, Ja-Ela', 'POL-90145', 'Reckless lane drift without signalling.', 'Settled', DATEADD(DAY, -268, GETDATE())),
    ('B9100162', 'WP BKK-3531', 'red_light', 3, 'Nawala Road, Rajagiriya', 'POL-90145', 'Crossed on red signal. Camera ref CAM-1918.', 'Settled', DATEADD(DAY, -232, GETDATE())),
    ('B9100162', 'WP BKK-3531', 'red_light', 3, 'Galle Road, Dehiwala', 'POL-90145', 'Crossed on red signal. Camera ref CAM-2317.', 'Settled', DATEADD(DAY, -206, GETDATE())),
    ('B9100162', 'WP BKK-3531', 'belt', 2, 'Kurunegala-Dambulla Road', 'POL-90145', 'Driver not wearing seatbelt.', 'Unpaid', DATEADD(DAY, -171, GETDATE())),
    ('B9100162', 'WP BKK-3531', 'red_light', 3, 'Borella Junction, Colombo 08', 'POL-90147', 'Crossed on red signal. Camera ref CAM-1563.', 'Unpaid', DATEADD(DAY, -122, GETDATE())),
    ('B9100162', 'WP BKK-3531', 'speeding', 4, 'Peradeniya Road, Kandy', 'POL-90145', 'Speed gun reading 128 km/h. Ref RD-2239.', 'Unpaid', DATEADD(DAY, -96, GETDATE())),
    ('B9100162', 'WP BKK-3531', 'belt', 2, 'Outer Circular Highway, Kaduwela', 'POL-90148', 'Driver not wearing seatbelt.', 'Unpaid', DATEADD(DAY, -51, GETDATE()));

    UPDATE d
    SET DemeritPoints = ISNULL(s.TotalPoints, 0),
        RiskStatus    = CASE WHEN ISNULL(s.TotalPoints, 0) >= 24 THEN 'HIGH RISK' ELSE 'NORMAL' END
    FROM Drivers d
    LEFT JOIN (SELECT DriverID, SUM(DemeritPointsAdded) AS TotalPoints
               FROM Violations GROUP BY DriverID) s ON s.DriverID = d.DriverID
    WHERE d.DriverID IN ('B9100001','B9100008','B9100015','B9100022','B9100029','B9100036','B9100043','B9100050','B9100057','B9100064','B9100071','B9100078','B9100085','B9100092','B9100099','B9100106','B9100113','B9100120','B9100127','B9100134','B9100141','B9100148','B9100155','B9100162');

    UPDATE v
    SET PendingFineBalance = ISNULL(f.Total, 0)
    FROM Vehicles v
    LEFT JOIN (SELECT RegistrationPlate,
                      SUM(CASE ViolationType
                              WHEN 'speeding'       THEN 2500
                              WHEN 'red_light'      THEN 2500
                              WHEN 'lane_departure' THEN 2000
                              WHEN 'dui'            THEN 25000
                              WHEN 'belt'           THEN 1000
                              ELSE 0 END) AS Total
               FROM Violations
               WHERE FineStatus = 'Unpaid'
               GROUP BY RegistrationPlate) f ON f.RegistrationPlate = v.RegistrationPlate
    WHERE v.RegistrationPlate IN ('WP CAD-2824','WP KR-5012','CP KA-4257','SP GB-6514','NW LB-4150','WP BEE-4598','SG PB-3266','NC KA-6573','UP PA-2832','WP CBA-4981','EP KB-8886','WP KT-4910','CP BCC-7267','SP GC-6344','WP CAF-7790','NW KV-3267','WP BJA-8956','CP KB-1207','SP GD-7625','WP CBG-8699','SG PC-2899','WP KZ-3434','NW LC-1753','WP BKK-3531','WP CAZ-1001','CP KC-2002','SP GE-3003');
END
GO


/* ---------- More violations for existing licences ---------- */

IF NOT EXISTS (SELECT 1 FROM Violations WHERE OfficerRemarks LIKE '%Ref EX-%')
BEGIN
    INSERT INTO Violations (DriverID, RegistrationPlate, ViolationType, DemeritPointsAdded,
                            RecordedLocation, WitnessOfficerBadgeID, OfficerRemarks, FineStatus, ViolationDate)
    VALUES
    ('B1234567', 'WP CAA-7892', 'speeding', 4, 'Anuradhapura Road, Kurunegala', 'POL-90145', 'Excessive speed on highway, 78 km/h. Ref EX-3840.', 'Unpaid', DATEADD(DAY, -26, GETDATE())),
    ('B1234567', 'WP CAA-7892', 'speeding', 4, 'Kaduwela Junction', 'POL-90148', 'Excessive speed on highway, 99 km/h. Ref EX-3088.', 'Unpaid', DATEADD(DAY, -59, GETDATE())),
    ('B1234567', 'WP CAA-7892', 'speeding', 4, 'Havelock Road, Narahenpita', 'POL-90145', 'Excessive speed on highway, 126 km/h. Ref EX-3846.', 'Unpaid', DATEADD(DAY, -6, GETDATE())),
    ('B3456789', 'SP GA-1234', 'dui', 10, 'Anuradhapura Road, Kurunegala', 'POL-90146', 'Breath test positive, vehicle held. Ref EX-3047.', 'Unpaid', DATEADD(DAY, -4, GETDATE())),
    ('B3456789', 'SP GA-1234', 'lane_departure', 3, 'Havelock Road, Narahenpita', 'POL-90146', 'Reckless lane drift, no signal. Ref EX-3105.', 'Unpaid', DATEADD(DAY, -10, GETDATE())),
    ('B3456789', 'SP GA-1234', 'speeding', 4, 'Outer Circular Highway, Athurugiriya', 'POL-90148', 'Excessive speed on highway, 80 km/h. Ref EX-3633.', 'Settled', DATEADD(DAY, -36, GETDATE())),
    ('B3456789', 'SP GA-1234', 'belt', 2, 'Marine Drive, Bambalapitiya', 'POL-90146', 'Rider without protective helmet. Ref EX-3370.', 'Unpaid', DATEADD(DAY, -28, GETDATE())),
    ('B4567890', 'CP BDF-5566', 'speeding', 4, 'Parliament Road, Battaramulla', 'POL-90148', 'Excessive speed on highway, 110 km/h. Ref EX-3896.', 'Unpaid', DATEADD(DAY, -6, GETDATE())),
    ('B4567890', 'CP BDF-5566', 'speeding', 4, 'Parliament Road, Battaramulla', 'POL-90146', 'Excessive speed on highway, 125 km/h. Ref EX-3775.', 'Unpaid', DATEADD(DAY, -8, GETDATE())),
    ('B4567890', 'CP BDF-5566', 'lane_departure', 3, 'Nawala Junction, Nugegoda', 'POL-90148', 'Reckless lane drift, no signal. Ref EX-3711.', 'Settled', DATEADD(DAY, -3, GETDATE())),
    ('B4567890', 'CP BDF-5566', 'belt', 2, 'High Level Road, Kirulapone', 'POL-90145', 'Seatbelt not worn by driver. Ref EX-3713.', 'Settled', DATEADD(DAY, -5, GETDATE())),
    ('B6789012', 'NW LA-3344', 'speeding', 4, 'Pannipitiya Junction', 'POL-90147', 'Excessive speed on highway, 129 km/h. Ref EX-3733.', 'Unpaid', DATEADD(DAY, -42, GETDATE())),
    ('B6789012', 'NW LA-3344', 'belt', 2, 'Outer Circular Highway, Athurugiriya', 'POL-90147', 'Seatbelt not worn by driver. Ref EX-3060.', 'Unpaid', DATEADD(DAY, -23, GETDATE())),
    ('B6789012', 'NW LA-3344', 'speeding', 4, 'Negombo Road, Seeduwa', 'POL-90148', 'Speed camera capture 135 km/h, limit 50. Ref EX-3170.', 'Settled', DATEADD(DAY, -26, GETDATE())),
    ('B6789012', 'NW LA-3344', 'speeding', 4, 'Kaduwela Junction', 'POL-90147', 'Over-speeding: radar reading 127 km/h in a 70 km/h zone. Ref EX-3723.', 'Settled', DATEADD(DAY, -57, GETDATE())),
    ('B7890123', 'WP CBN-7721', 'speeding', 4, 'Colombo-Katunayake Expressway, Peliyagoda', 'POL-90145', 'Over-speeding: radar reading 94 km/h in a 60 km/h zone. Ref EX-3237.', 'Unpaid', DATEADD(DAY, -10, GETDATE())),
    ('B7890123', 'WP CBN-7721', 'belt', 2, 'Anuradhapura Road, Kurunegala', 'POL-90148', 'Rider without protective helmet. Ref EX-3467.', 'Unpaid', DATEADD(DAY, -24, GETDATE())),
    ('B8901234', 'SG PH-2210', 'red_light', 3, 'Matara Road, Hikkaduwa', 'POL-90148', 'Crossed junction on red signal. Camera ref EX-3477.', 'Unpaid', DATEADD(DAY, -31, GETDATE())),
    ('B8901234', 'SG PH-2210', 'speeding', 4, 'Southern Expressway, Welipenna', 'POL-90145', 'Over-speeding: radar reading 115 km/h in a 70 km/h zone. Ref EX-3490.', 'Unpaid', DATEADD(DAY, -10, GETDATE())),
    ('B8901234', 'SG PH-2210', 'belt', 2, 'High Level Road, Kirulapone', 'POL-90147', 'Seatbelt not worn by driver. Ref EX-3658.', 'Settled', DATEADD(DAY, -24, GETDATE())),
    ('B9100001', 'WP CAD-2824', 'speeding', 4, 'Colombo-Katunayake Expressway, Peliyagoda', 'POL-90146', 'Over-speeding: radar reading 140 km/h in a 70 km/h zone. Ref EX-3651.', 'Unpaid', DATEADD(DAY, -23, GETDATE())),
    ('B9100001', 'WP CAD-2824', 'lane_departure', 3, 'Galle Road, Mount Lavinia', 'POL-90145', 'Reckless lane drift, no signal. Ref EX-3364.', 'Unpaid', DATEADD(DAY, -48, GETDATE())),
    ('B9100001', 'WP CAD-2824', 'belt', 2, 'Nawala Junction, Nugegoda', 'POL-90147', 'Seatbelt not worn by driver. Ref EX-3827.', 'Unpaid', DATEADD(DAY, -17, GETDATE())),
    ('B9100008', 'WP KR-5012', 'speeding', 4, 'Matara Road, Hikkaduwa', 'POL-90145', 'Speed camera capture 97 km/h, limit 70. Ref EX-3209.', 'Unpaid', DATEADD(DAY, -15, GETDATE())),
    ('B9100008', 'WP KR-5012', 'red_light', 3, 'Outer Circular Highway, Athurugiriya', 'POL-90148', 'Crossed junction on red signal. Camera ref EX-3801.', 'Unpaid', DATEADD(DAY, -52, GETDATE())),
    ('B9100015', 'CP KA-4257', 'red_light', 3, 'High Level Road, Kirulapone', 'POL-90146', 'Ran red light, officer witnessed. Ref EX-3761.', 'Unpaid', DATEADD(DAY, -6, GETDATE())),
    ('B9100015', 'CP KA-4257', 'speeding', 4, 'Union Place, Colombo 02', 'POL-90148', 'Over-speeding: radar reading 131 km/h in a 60 km/h zone. Ref EX-3626.', 'Settled', DATEADD(DAY, -2, GETDATE())),
    ('B9100015', 'CP KA-4257', 'red_light', 3, 'Colombo-Kandy Road, Ragama', 'POL-90146', 'Crossed junction on red signal. Camera ref EX-3818.', 'Unpaid', DATEADD(DAY, -10, GETDATE())),
    ('B9100022', 'SP GB-6514', 'speeding', 4, 'Colombo-Katunayake Expressway, Peliyagoda', 'POL-90147', 'Speed camera capture 99 km/h, limit 70. Ref EX-3513.', 'Unpaid', DATEADD(DAY, -2, GETDATE())),
    ('B9100022', 'SP GB-6514', 'belt', 2, 'Negombo Road, Seeduwa', 'POL-90148', 'Seatbelt not worn by driver. Ref EX-3919.', 'Settled', DATEADD(DAY, -27, GETDATE())),
    ('B9100029', 'NW LB-4150', 'belt', 2, 'Galle Road, Mount Lavinia', 'POL-90146', 'Seatbelt not worn by driver. Ref EX-3623.', 'Unpaid', DATEADD(DAY, -10, GETDATE())),
    ('B9100029', 'NW LB-4150', 'speeding', 4, 'Peradeniya Road, Kandy', 'POL-90148', 'Excessive speed on highway, 87 km/h. Ref EX-3333.', 'Unpaid', DATEADD(DAY, -31, GETDATE())),
    ('B9100036', 'WP BEE-4598', 'speeding', 4, 'Colombo-Kandy Road, Ragama', 'POL-90148', 'Over-speeding: radar reading 107 km/h in a 50 km/h zone. Ref EX-3790.', 'Settled', DATEADD(DAY, -16, GETDATE())),
    ('B9100036', 'WP BEE-4598', 'speeding', 4, 'Peradeniya Road, Kandy', 'POL-90146', 'Over-speeding: radar reading 128 km/h in a 70 km/h zone. Ref EX-3627.', 'Settled', DATEADD(DAY, -49, GETDATE())),
    ('B9100036', 'WP BEE-4598', 'speeding', 4, 'Colombo-Katunayake Expressway, Peliyagoda', 'POL-90147', 'Excessive speed on highway, 140 km/h. Ref EX-3519.', 'Settled', DATEADD(DAY, -29, GETDATE())),
    ('B9100036', 'WP BEE-4598', 'speeding', 4, 'Pannipitiya Junction', 'POL-90148', 'Speed camera capture 89 km/h, limit 80. Ref EX-3124.', 'Unpaid', DATEADD(DAY, -54, GETDATE())),
    ('B9100043', 'SG PB-3266', 'speeding', 4, 'Colombo-Kandy Road, Ragama', 'POL-90146', 'Over-speeding: radar reading 99 km/h in a 70 km/h zone. Ref EX-3802.', 'Settled', DATEADD(DAY, -28, GETDATE())),
    ('B9100043', 'SG PB-3266', 'red_light', 3, 'Colombo-Kandy Road, Ragama', 'POL-90148', 'Ran red light, officer witnessed. Ref EX-3224.', 'Unpaid', DATEADD(DAY, -10, GETDATE())),
    ('B9100050', 'NC KA-6573', 'speeding', 4, 'Kaduwela Junction', 'POL-90146', 'Excessive speed on highway, 127 km/h. Ref EX-3347.', 'Unpaid', DATEADD(DAY, -11, GETDATE())),
    ('B9100050', 'NC KA-6573', 'red_light', 3, 'Negombo Road, Seeduwa', 'POL-90148', 'Ran red light, officer witnessed. Ref EX-3567.', 'Settled', DATEADD(DAY, -6, GETDATE())),
    ('B9100057', 'UP PA-2832', 'lane_departure', 3, 'Colombo-Katunayake Expressway, Peliyagoda', 'POL-90145', 'Unsafe overtaking over solid line. Ref EX-3115.', 'Unpaid', DATEADD(DAY, -22, GETDATE())),
    ('B9100057', 'UP PA-2832', 'speeding', 4, 'Southern Expressway, Kahathuduwa', 'POL-90148', 'Over-speeding: radar reading 95 km/h in a 70 km/h zone. Ref EX-3773.', 'Settled', DATEADD(DAY, -18, GETDATE())),
    ('B9100064', 'WP CBA-4981', 'lane_departure', 3, 'Baseline Road, Dematagoda', 'POL-90146', 'Unsafe overtaking over solid line. Ref EX-3285.', 'Unpaid', DATEADD(DAY, -10, GETDATE())),
    ('B9100064', 'WP CBA-4981', 'speeding', 4, 'Union Place, Colombo 02', 'POL-90146', 'Over-speeding: radar reading 83 km/h in a 70 km/h zone. Ref EX-3085.', 'Unpaid', DATEADD(DAY, -18, GETDATE())),
    ('B9100064', 'WP CBA-4981', 'speeding', 4, 'Anuradhapura Road, Kurunegala', 'POL-90148', 'Over-speeding: radar reading 130 km/h in a 50 km/h zone. Ref EX-3347.', 'Unpaid', DATEADD(DAY, -56, GETDATE())),
    ('B9100071', 'EP KB-8886', 'speeding', 4, 'Southern Expressway, Welipenna', 'POL-90147', 'Excessive speed on highway, 102 km/h. Ref EX-3992.', 'Unpaid', DATEADD(DAY, -3, GETDATE())),
    ('B9100071', 'EP KB-8886', 'speeding', 4, 'Negombo Road, Seeduwa', 'POL-90146', 'Speed camera capture 111 km/h, limit 60. Ref EX-3296.', 'Unpaid', DATEADD(DAY, -13, GETDATE())),
    ('B9100071', 'EP KB-8886', 'red_light', 3, 'Galle Road, Mount Lavinia', 'POL-90146', 'Crossed junction on red signal. Camera ref EX-3015.', 'Settled', DATEADD(DAY, -52, GETDATE())),
    ('B9100078', 'WP KT-4910', 'speeding', 4, 'Negombo Road, Seeduwa', 'POL-90145', 'Speed camera capture 95 km/h, limit 60. Ref EX-3275.', 'Unpaid', DATEADD(DAY, -3, GETDATE())),
    ('B9100078', 'WP KT-4910', 'red_light', 3, 'Marine Drive, Bambalapitiya', 'POL-90146', 'Ran red light, officer witnessed. Ref EX-3988.', 'Unpaid', DATEADD(DAY, -22, GETDATE())),
    ('B9100078', 'WP KT-4910', 'speeding', 4, 'Kandy Road, Kegalle', 'POL-90146', 'Speed camera capture 120 km/h, limit 50. Ref EX-3486.', 'Unpaid', DATEADD(DAY, -1, GETDATE())),
    ('B9100085', 'CP BCC-7267', 'speeding', 4, 'Nawala Junction, Nugegoda', 'POL-90145', 'Over-speeding: radar reading 77 km/h in a 60 km/h zone. Ref EX-3652.', 'Unpaid', DATEADD(DAY, -6, GETDATE())),
    ('B9100085', 'CP BCC-7267', 'belt', 2, 'Kandy Road, Kegalle', 'POL-90145', 'Seatbelt not worn by driver. Ref EX-3501.', 'Unpaid', DATEADD(DAY, -36, GETDATE())),
    ('B9100085', 'CP BCC-7267', 'speeding', 4, 'Peradeniya Road, Kandy', 'POL-90145', 'Excessive speed on highway, 140 km/h. Ref EX-3675.', 'Settled', DATEADD(DAY, -48, GETDATE())),
    ('B9100092', 'SP GC-6344', 'belt', 2, 'Colombo-Kandy Road, Ragama', 'POL-90146', 'Rider without protective helmet. Ref EX-3785.', 'Unpaid', DATEADD(DAY, -19, GETDATE())),
    ('B9100092', 'SP GC-6344', 'speeding', 4, 'High Level Road, Kirulapone', 'POL-90148', 'Speed camera capture 74 km/h, limit 70. Ref EX-3469.', 'Unpaid', DATEADD(DAY, -60, GETDATE())),
    ('B9100092', 'SP GC-6344', 'lane_departure', 3, 'Peradeniya Road, Kandy', 'POL-90147', 'Reckless lane drift, no signal. Ref EX-3145.', 'Unpaid', DATEADD(DAY, -14, GETDATE())),
    ('B9100099', 'WP CAF-7790', 'speeding', 4, 'High Level Road, Kirulapone', 'POL-90148', 'Excessive speed on highway, 109 km/h. Ref EX-3381.', 'Unpaid', DATEADD(DAY, -58, GETDATE())),
    ('B9100099', 'WP CAF-7790', 'speeding', 4, 'Colombo-Kandy Road, Ragama', 'POL-90145', 'Speed camera capture 107 km/h, limit 50. Ref EX-3287.', 'Settled', DATEADD(DAY, -24, GETDATE())),
    ('B9100106', 'NW KV-3267', 'speeding', 4, 'Havelock Road, Narahenpita', 'POL-90146', 'Over-speeding: radar reading 119 km/h in a 70 km/h zone. Ref EX-3828.', 'Unpaid', DATEADD(DAY, -21, GETDATE())),
    ('B9100106', 'NW KV-3267', 'lane_departure', 3, 'Kandy Road, Kegalle', 'POL-90147', 'Unsafe overtaking over solid line. Ref EX-3385.', 'Unpaid', DATEADD(DAY, -25, GETDATE())),
    ('B9100113', 'WP BJA-8956', 'speeding', 4, 'Parliament Road, Battaramulla', 'POL-90146', 'Excessive speed on highway, 110 km/h. Ref EX-3285.', 'Unpaid', DATEADD(DAY, -1, GETDATE())),
    ('B9100120', 'CP KB-1207', 'lane_departure', 3, 'Anuradhapura Road, Kurunegala', 'POL-90148', 'Reckless lane drift, no signal. Ref EX-3381.', 'Unpaid', DATEADD(DAY, -6, GETDATE())),
    ('B9100127', 'SP GD-7625', 'belt', 2, 'Colombo-Kandy Road, Ragama', 'POL-90145', 'Rider without protective helmet. Ref EX-3904.', 'Unpaid', DATEADD(DAY, -36, GETDATE())),
    ('B9100134', 'WP CBG-8699', 'speeding', 4, 'Colombo-Kandy Road, Ragama', 'POL-90148', 'Speed camera capture 133 km/h, limit 50. Ref EX-3417.', 'Settled', DATEADD(DAY, -3, GETDATE())),
    ('B9100134', 'WP CBG-8699', 'belt', 2, 'Kandy Road, Kegalle', 'POL-90148', 'Seatbelt not worn by driver. Ref EX-3712.', 'Unpaid', DATEADD(DAY, -10, GETDATE())),
    ('B9100148', 'WP KZ-3434', 'speeding', 4, 'Kaduwela Junction', 'POL-90145', 'Over-speeding: radar reading 111 km/h in a 70 km/h zone. Ref EX-3424.', 'Unpaid', DATEADD(DAY, -27, GETDATE())),
    ('B9100148', 'WP KZ-3434', 'speeding', 4, 'Galle Road, Mount Lavinia', 'POL-90148', 'Excessive speed on highway, 123 km/h. Ref EX-3964.', 'Unpaid', DATEADD(DAY, -26, GETDATE())),
    ('B9100148', 'WP KZ-3434', 'lane_departure', 3, 'Southern Expressway, Welipenna', 'POL-90146', 'Reckless lane drift, no signal. Ref EX-3471.', 'Unpaid', DATEADD(DAY, -8, GETDATE())),
    ('B9100148', 'WP KZ-3434', 'speeding', 4, 'Union Place, Colombo 02', 'POL-90147', 'Over-speeding: radar reading 122 km/h in a 50 km/h zone. Ref EX-3586.', 'Settled', DATEADD(DAY, -36, GETDATE())),
    ('B9100155', 'NW LC-1753', 'speeding', 4, 'Southern Expressway, Welipenna', 'POL-90145', 'Speed camera capture 108 km/h, limit 60. Ref EX-3533.', 'Unpaid', DATEADD(DAY, -10, GETDATE())),
    ('B9100155', 'NW LC-1753', 'lane_departure', 3, 'Baseline Road, Dematagoda', 'POL-90148', 'Reckless lane drift, no signal. Ref EX-3857.', 'Unpaid', DATEADD(DAY, -32, GETDATE())),
    ('B9100155', 'NW LC-1753', 'speeding', 4, 'Union Place, Colombo 02', 'POL-90146', 'Excessive speed on highway, 121 km/h. Ref EX-3925.', 'Settled', DATEADD(DAY, -39, GETDATE())),
    ('B9100155', 'NW LC-1753', 'speeding', 4, 'Havelock Road, Narahenpita', 'POL-90146', 'Speed camera capture 97 km/h, limit 80. Ref EX-3187.', 'Unpaid', DATEADD(DAY, -40, GETDATE())),
    ('B9100162', 'WP BKK-3531', 'belt', 2, 'Colombo-Katunayake Expressway, Peliyagoda', 'POL-90146', 'Rider without protective helmet. Ref EX-3153.', 'Unpaid', DATEADD(DAY, -11, GETDATE())),
    ('B9100162', 'WP BKK-3531', 'belt', 2, 'Union Place, Colombo 02', 'POL-90148', 'Seatbelt not worn by driver. Ref EX-3399.', 'Settled', DATEADD(DAY, -54, GETDATE())),
    ('B9100162', 'WP BKK-3531', 'speeding', 4, 'Pannipitiya Junction', 'POL-90147', 'Speed camera capture 111 km/h, limit 60. Ref EX-3435.', 'Unpaid', DATEADD(DAY, -42, GETDATE()));

    UPDATE d
    SET DemeritPoints = ISNULL(s.TotalPoints, 0),
        RiskStatus    = CASE WHEN ISNULL(s.TotalPoints, 0) >= 24 THEN 'HIGH RISK' ELSE 'NORMAL' END
    FROM Drivers d
    LEFT JOIN (SELECT DriverID, SUM(DemeritPointsAdded) AS TotalPoints
               FROM Violations GROUP BY DriverID) s ON s.DriverID = d.DriverID
    WHERE d.DriverID IN ('B1234567','B3456789','B4567890','B6789012','B7890123','B8901234','B9100001','B9100008','B9100015','B9100022','B9100029','B9100036','B9100043','B9100050','B9100057','B9100064','B9100071','B9100078','B9100085','B9100092','B9100099','B9100106','B9100113','B9100120','B9100127','B9100134','B9100148','B9100155','B9100162');

    UPDATE v
    SET PendingFineBalance = ISNULL(f.Total, 0)
    FROM Vehicles v
    LEFT JOIN (SELECT RegistrationPlate,
                      SUM(CASE ViolationType
                              WHEN 'speeding'       THEN 2500
                              WHEN 'red_light'      THEN 2500
                              WHEN 'lane_departure' THEN 2000
                              WHEN 'dui'            THEN 25000
                              WHEN 'belt'           THEN 1000
                              ELSE 0 END) AS Total
               FROM Violations
               WHERE FineStatus = 'Unpaid'
               GROUP BY RegistrationPlate) f ON f.RegistrationPlate = v.RegistrationPlate
    WHERE v.RegistrationPlate IN ('CP BCC-7267','CP BDF-5566','CP KA-4257','CP KB-1207','EP KB-8886','NC KA-6573','NW KV-3267','NW LA-3344','NW LB-4150','NW LC-1753','SG PB-3266','SG PH-2210','SP GA-1234','SP GB-6514','SP GC-6344','SP GD-7625','UP PA-2832','WP BEE-4598','WP BJA-8956','WP BKK-3531','WP CAA-7892','WP CAD-2824','WP CAF-7790','WP CBA-4981','WP CBG-8699','WP CBN-7721','WP KR-5012','WP KT-4910','WP KZ-3434');
END
GO


/* ---------- Check ---------- */
SELECT DriverID, FullName, DemeritPoints, RiskStatus FROM Drivers ORDER BY DemeritPoints DESC;
SELECT COUNT(*) AS TotalViolations FROM Violations;
GO
