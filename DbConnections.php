<?php
// MS SQL Server Database Connection Configuration
$serverName = "(localdb)\MSSQLLocalDB"; 
$database   = "Smart_traffic_System";
$username   = "your_db_username";        
$password   = "your_db_password";        

try {
    
    $conn = new PDO("sqlsrv:Server=$(localdb)\MSSQLLocalDB; Database=$Smart_traffic_System", $username, $password);
    
   
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

} catch (PDOException $e) {
   
    die("Database Connection Failed: " . $e->getMessage());
}
?>