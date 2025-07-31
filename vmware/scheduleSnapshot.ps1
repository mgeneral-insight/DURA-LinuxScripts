$ErrorActionPreference = "SilentlyContinue"
[System.Net.Http.HttpClient]::DefaultProxy = New-Object System.Net.WebProxy($null)
$vcenters = @("aar-winvc04.corp.duracell.com", "becn-wvvctrp03.corp.duracell.com", "cnnc-winvc01.corp.duracell.com", "dgwinvc03.corp.duracell.com", "heivcsa.corp.duracell.com")

function findVM {
    param ($vctr, $creds)
    $conn = connect-viserver -server $vctr -credential $creds
    $getvm = get-vm $vm
    disconnect-viserver * -Confirm:$false
    if ($getvm) {
        $script:foundvc = $vctr
        break
    }
}

clear-host
get-content -raw /opt/scripts/linux/logo.txt
write-host "This script will schedule a snapshot of a VM for the time and date you input."
write-host ""

$tktNum = read-host -prompt "Enter ticket number for the request (press ENTER to skip)"
$vm = read-host -Prompt "Enter name of VM to snapshot"
write-host "Searching vCenters for $vm..."
foreach ($vcenter in $vcenters) {
    if ( $vcenter -eq 'heivcsa.corp.duracell.com' ) {
        $securePassword = Get-Content '/opt/scripts/.credfiles/hei.cred' | ConvertTo-SecureString
        $credentials = New-Object System.Management.Automation.PSCredential ("administrator@heist.local", $securePassword)
    } else {
        $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
        $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
    }
    #write-host "`nSearching $vcenter"
    findVM -vctr $vcenter -creds $credentials
}
if ( $null -eq $foundvc ) {
    Write-Host "Virtual Machine $vm was not found on any vCenter. Check the VM name and make sure it is a VMware Virtual Machine."
    Read-Host "Press ENTER to Exit..."
    Exit 1
} else { write-host "Found $vm on $foundvc" }


Write-Host @"
---------- Select Time Zone ----------
1) Eastern Time Zone - EST/EDT - (US) 
2) Central Time Zone - CST/CDT - (US)
3) Central EUROPE Time Zone - CET/CEST - (EU)
4) China Standard Time Zone - (APAC)
---------------------------------------------
"@
read-host -Prompt ""
Do { $selection = Read-Host "Enter Time Zone for time to take snapshot (1-4)" }
Until (1..4 -contains $selection)

if ($selection -eq "1") { 
    $tz = "America/New_York" 
    $tzName = "Eastern Time Zone - EST/EDT - (US)"
} 
elseif ($selection -eq "2") { 
    $tz = "America/Chicago" 
    $tzName = "Central Time Zone - CST/CDT - (US)"
} 
elseif ($selection -eq "3") { 
    $tz = "Europe/Brussels" 
    $tzName = "Central EUROPE Time Zone - CET/CEST - (EU)"
} 
elseif ($selection -eq "4") { 
    $tz = "Asia/Shanghai" 
    $tzName = "China Standard Time Zone - (APAC)"
} 

function Test-TimeInput {
    param(
        [string]$TimeInput
    )
    return $TimeInput -as [DateTime] -ne $null
}
do {
    $timeString = Read-Host -Prompt "Enter time to take the snapshot in the timezone you selected above (HH:MM or HH:MM AM/PM)"
} until (Test-TimeInput -TimeInput $timeString)

function Test-Date {
    param (
        [string]$DateInput
    )
    return $DateInput -as [DateTime] -ne $null
}
do {
    $dateString = Read-Host -Prompt 'Enter date to take the snapshot in the timezone you selected above (mm/dd/yyyy)'
} until (Test-Date -DateInput $dateString)

$inDT = "$dateString $timeString"
#write-host "inDT - $inDT"
$inDTnice = [datetime]$inDT
#write-host "inDTnice - $inDTnice"
#write-host "tz - $tz"
$outTZ = [System.TimeZoneInfo]::GetSystemTimeZones() | Where-Object { $_.Id -eq "America/New_York" }
if ($tz -eq "Eastern Standard Time") {
    $outDT = [datetime]$inDT
} else {
    $inTZ = [System.TimeZoneInfo]::GetSystemTimeZones() | Where-Object { $_.Id -eq $tz }
    #write-host "inTZ - $inTZ"
    $outDT = [System.TimeZoneInfo]::ConvertTime($inDT, $inTZ, $outTZ)
}
#write-host "outDT - $outDT"
[int]$createTime = [long](Get-Date -Date $outDT -UFormat %s)
#write-host "createTime - $createTime"
$currentTime = get-date -UFormat %s

if ($currentTime -gt $createTime) {
    write-host "ERROR: Scheduled time is in the past" -foregroundcolor red
    exit 1
}

$notifyEmail = read-host -prompt "Enter email addresses to notify once snapshot has been taken (sepearate multiple addresses with semicolon ;) Press ENTER to skip"
while ($notifyEmail.contains(",")) { $notifyEmail = read-host -prompt "Enter email addresses to notify once snapshot has been taken (sepearate multiple addresses with semicolon ; DO NOT USE COMMAs ,) Press ENTER to skip." }

[int]$keepDays = read-host -prompt "Enter number of days to keep snapshot after it is taken. The snapshot will be automatically deleted after this time. Press ENTER to skip automatic deletion"

if ($keepDays) { 
    $keepDaysMSG = "Snapshot will be automatically deleted $keepDays days after creation." 
    $keepTime = $keepDays * 86400
    $removeTime = $createTime + $keepTime
} 
else { $keepDaysMSG = "Snapshot WILL NOT be deleted automatically."}

$filename = "/opt/scripts/.scheduledSnaps/$vm-$createTime.csv"
new-item $filename -ItemType File | Out-Null
Invoke-Command{chmod 666 $filename}

set-content $filename 'vCenter, VM, SnapName, ScheduledTime, RemoveTime, KeepDays, NotifyEmail, Ticket'
add-content $filename "$foundvc, $vm, Insight-Scheduled-$createTime-$tktNum, $createTime, $removeTime, $keepDays, $notifyEmail, $tktNum"

write-host "Snapshot has been scheduled successfully" -foregroundcolor green
write-host "VM Name: $vm"
write-host "Scheduled for: $inDTnice $tzName"
write-host $keepDaysMSG

$From = "Insight-Automations@duracell.com"
$Subject = "$tktNum New Snapshot Scheduled - $vm"
$Body = @"
A VMWare Snapshot has been scheduled:

VM: $vm
Scheduled for: $inDTnice $tzName
`r`n$keepDaysMSG
"@

$SMTPServer = "smtp.duracell.com"
$SMTPPort = "25"
if ($notifyEmail) { 
    $notifyEmailarray = $notifyEmail -split ";"
    Send-MailMessage -From $From -to $notifyEmailarray -Subject $Subject -Body $Body -SmtpServer $SMTPServer -Port $SMTPPort -WarningAction SilentlyContinue
}
Send-MailMessage -From $From -to "michael.general@insight.com", "shaun.fogleman@insight.com" -Subject $Subject -Body $Body -SmtpServer $SMTPServer -Port $SMTPPort -WarningAction SilentlyContinue

