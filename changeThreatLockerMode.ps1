clear-host
get-content -raw /opt/scripts/linux/logo.txt

# Get script path (works for both .ps1 and .exe)
if ($MyInvocation.MyCommand.Path) {
    $ScriptPath = $MyInvocation.MyCommand.Path
} else {
    $ScriptPath = [System.Reflection.Assembly]::GetEntryAssembly().Location
}

$ScriptVersion = "1.0.3"
$ScriptHost = "LGGALV011"
$ScriptUser = "Insight"
$LocalTime  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$Report     = @()

Write-Host @"
This script will change the mode of ThreatLocker on the server you input. 
It performs the following steps:
- Query ThreatLocker to find server and make sure ThreatLocker is installed
- Get the current mode of ThreatLocker
- If it is currently Secure Mode it will ask if you want to change to Learning Mode (non-blocking) for 4 hours
- If it is currently in Learning Mode it will ask if you want to change to Secure Mode (Blocking) immediately
"@

if (!($server)) { $server = Read-Host -Prompt "Enter Server Name" }

# ====== Shared API Config ======
$searchUri      = "https://portalapi.h.threatlocker.com/portalApi/Computer/ComputerGetByAllParameters"
$maintenanceUri = "https://portalapi.h.threatlocker.com/portalapi/MaintenanceMode/MaintenanceModeInsert"
$token = "F774A8C5F8CCA5D6F48C50175D776AF77C9AE1FEE0263649643C0983567C52E0"  # Replace with your actual API token
$headers = @{
    "Authorization" = "$token"
    "Content-Type"  = "application/json"
}

$searchBody = @{
    pageSize = 25
    pageNumber = 1
    searchText = $server
    computerGroup = "CDAA4C7B-0D82-4368-B3DB-16F583848827"
    orderBy = "computername"
    computerId = "00000000-0000-0000-0000-000000000000"
    childOrganizations = $false
    showLastCheckIn = $true
    isAscending = $true
    searchBy = 1
    kindOfAction = ""
    hasComputerPassword = $false
    showDeleted = $false
} | ConvertTo-Json -Depth 10

try {
    $searchResponse = Invoke-RestMethod -Method Post -Uri $searchUri -Headers $headers -Body $searchBody

    if (-not $searchResponse.computerId) {
        Write-Host " No computerId found for $server" -ForegroundColor Red
        $Report += "<tr><td>$server</td><td><span style='color:red'> No computerId found</span></td></tr>"
        continue
    }

    $computerId   = $searchResponse.computerId
    $computerName = if ($searchResponse.computerName) { $searchResponse.computerName } else { $server }

    # Try a few possible fields for "mode"
    $mode = $null
    if ($searchResponse.currentMode) { $mode = $searchResponse.currentMode }
    elseif ($searchResponse.mode) { $mode = $searchResponse.mode }
    elseif ($searchResponse.maintenanceMode) { $mode = $searchResponse.maintenanceMode }
    elseif ($searchResponse.state) { $mode = $searchResponse.state }

    Write-Host "   Found computerId: $computerId" -ForegroundColor Yellow

    if ($mode) {
        Write-Host "   Current Mode: $mode" -ForegroundColor Green
    } else {
        $mode = "Unknown"
        Write-Host "    Could not determine current mode (field missing in API response)" -ForegroundColor DarkYellow
    }

} catch {
    Write-Host "   Failed to retrieve computer info for $server - $($_.Exception.Message)" -ForegroundColor Red
    $Report += "<tr><td>$server</td><td><span style='color:red'> Failed to retrieve computer info</span></td></tr>"
    continue
}

# ====== Decide what to do based on mode ======
$targetMode = $null
$duration   = $null
$maintenanceTypeId = $null

if ($mode -like "*Application Control Learning Mode*") {
    $confirm = Read-Host "Do you want to change $server to Secure Mode? (y/n)"
    if ($confirm -in @("y","Y")) {
        $targetMode = "Secure Mode"
        $duration = 1   # minute
        $maintenanceTypeId = 3
    }
}
elseif ($mode -like "*Secure*") {
    $confirm = Read-Host "Do you want to change $server to Learning Mode? (y/n)"
    if ($confirm -in @("y","Y")) {
        $targetMode = "Learning Mode"
        $duration = 4   # hours
        $maintenanceTypeId = 3
    }
}
else {
    Write-Host "   Mode $mode not handled. Skipping." -ForegroundColor DarkYellow
    continue
}

if (-not $targetMode) {
    Write-Host "   Skipping $server" -ForegroundColor Gray
    $Report += "<tr><td>$server</td><td><span style='color:gray'> Skipping</span></td></tr>"
    continue
}

# ====== Date/Time Handling ======
$startDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd THH:mm:ssZ")
if ($duration -eq 1) {
    $endDateTime = (Get-Date).ToUniversalTime().AddMinutes(1).ToString("yyyy-MM-dd THH:mm:ssZ")
} else {
    $endDateTime = (Get-Date).ToUniversalTime().AddHours(4).ToString("yyyy-MM-dd THH:mm:ssZ")
}

# ====== Prepare maintenance body ======
$maintenanceBody = @{
    allUsers = $true
    automaticApplication = $true
    automaticApplicationType = 2
    computerId = $computerId
    createNewApplication = $false
    endDateTime = $endDateTime
    existingApplication = @{
        applicationId = "00000000-0000-0000-0000-000000000000"
        name = ""
    }
    maintenanceTypeId = $maintenanceTypeId
    newApplication = @{
        applicationId = "00000000-0000-0000-0000-000000000000"
        applicationName = ""
        createApplicationOnly = $false
        appliesToId = "00000000-0000-0000-0000-000000000000"
    }
    permitEnd = $false
    startDateTime = $startDateTime
    useExistingApplication = $false
    usersList = @("string")
    computerDateTime = $startDateTime
} | ConvertTo-Json -Depth 5

try {
    Invoke-RestMethod -Method Post -Uri $maintenanceUri -Headers $headers -Body $maintenanceBody | Out-Null

    if ($targetMode -eq "Secure Mode") {
        Write-Host "   $server successfully switched to $targetMode" -ForegroundColor Green
    }
    else {
        Write-Host "   $server successfully switched to $targetMode for $duration hours" -ForegroundColor Green
    }

    $Report += "<tr><td>$server</td><td><span style='color:green'> Current Mode: $mode - Successfully switched to $targetMode</span></td></tr>"
} catch {
    Write-Host "   Request failed for $server - $($_.Exception.Message)" -ForegroundColor Red
    $Report += "<tr><td>$server</td><td><span style='color:red'> Request failed - $($_.Exception.Message)</span></td></tr>"
}

# ====== Build HTML Email ======
$body = @"
<html>
<head>
<style>
    body { font-family: Arial, sans-serif; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ddd; padding: 8px; }
    th { background-color: #f2f2f2; text-align: left; }
</style>
</head>
<body>
<p><b>Script Version:</b> $ScriptVersion<br>
<b>Script Path:</b> $ScriptPath<br>
<b>Script executed on:</b> $ScriptHost<br>
<b>Script executed by:</b> $ScriptUser<br>
<b>Script executed Local Time (Device):</b> $LocalTime</p>

<table>
<tr><th>Hostname</th><th>Result</th></tr>
$($Report -join "`r`n")
</table>

</body>
</html>
"@

# ====== Send summary email ======
try {
    Send-MailMessage -SmtpServer "smtp.duracell.com" `
                     -From no-reply@duracell.com `
                     -To michael.general@insight.com `
                     -Subject "Threatlocker Script Execution" `
                     -Body $body `
                     -BodyAsHtml
                     -ErrorAction SilentlyContinue
    Write-Host " Summary email sent successfully to Duracell IT Security." -ForegroundColor Cyan
} catch {
    Write-Host " Failed to send summary email - $($_.Exception.Message)" -ForegroundColor Red
}

Pause