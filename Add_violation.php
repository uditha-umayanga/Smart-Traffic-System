<?php
include 'DbConnections.php'; 
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $licNo = $_POST['licNo'];
    try {
       
        $sql = "INSERT INTO Violations (DriverID, RegistrationPlate, ViolationType, RecordedLocation, WitnessOfficerBadgeID, OfficerRemarks) 
                VALUES (:licNo, :vehNo, :violationType, :recordedLocation, :witnessOfficer, :notes)";
        
        $stmt = $conn->prepare($sql);
        
        
        $stmt->execute([
            ':licNo' => $_POST['licNo'],
            ':vehNo' => $_POST['vehNo'],
            ':violationType' => $_POST['violationType'],
            ':recordedLocation' => $_POST['recordedLocation'],
            ':witnessOfficer' => $_POST['witnessOfficer'],
            ':notes' => $_POST['notes']
        ]);

        echo "<script>alert('Violation recorded successfully!'); window.location.href='add-violation.html';</script>";
        
    } catch (PDOException $e) {
        echo "Error: " . $e.getMessage();
    }
}
?>