# Load SSAS DLL
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices")
# Create SSAS Server Object
$serverAS = New-Object Microsoft.AnalysisServices.Server
# Connect to the SSAS Server instance (using either name\Instance or IP:Port)
$serverAS.connect("SQL\MSSQL")
# Displays all database names (further properties like last processed etc. are also available)
$serverAS.databases | select-Object Name

# The next view lines do the Drop
foreach($db in $serverAS.databases) {
  $db.Drop()
}