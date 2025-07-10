$ErrorActionPreference = "SilentlyContinue"
[System.Net.Http.HttpClient]::DefaultProxy = New-Object System.Net.WebProxy($null)
$vcenters = @'
aar-winvc04.corp.duracell.com
becn-wvvctrp03.corp.duracell.com
cnnc-winvc01.corp.duracell.com
dgwinvc03.corp.duracell.com
heivcsa.corp.duracell.com
'@ -split "`r`n"

function findVM {
    param ($vctr, $creds)
#    write-host "-connecting to $vctr - creds=$creds - vm=$vm"
    $conn = connect-viserver -server $vctr -credential $creds
#    Write-host $conn
    $getvm = get-vm $vm
#    write-host $getvm
    disconnect-viserver * -Confirm:$false
    if ( $null -eq $getvm ) {
        write-host "... not found on $vctr"
    } else {
        $script:foundvc = $vctr
        break
    }
}

write-host "This script will schedule a snapshot of a VM for the time and date you input."
$vm = read-host -Prompt "Enter name of VM to snapshot"

foreach ($vcenter in $vcenters) {
    if ( $vcenter -eq 'heivcsa.corp.duracell.com' ) {
        $securePassword = Get-Content '/opt/scripts/vmware/hei.cred' | ConvertTo-SecureString
        $credentials = New-Object System.Management.Automation.PSCredential ("administrator@heist.local", $securePassword)
    } else {
        $securePassword = Get-Content '/opt/scripts/vmware/vctr.cred' | ConvertTo-SecureString
        $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
    }
    write-host "`nSearching $vcenter"
    findVM -vctr $vcenter -creds $credentials
}
if ( $null -eq $foundvc ) {
    Write-Host "Virtual Machine $vm was not found on any vCenter. Check the VM name and make sure it is a VMware Virtual Machine."
    Read-Host "Press ENTER to Exit..."
    Exit 1
}


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

if ($selection -eq "1") { $tz = "Eastern Standard Time" } 
elseif ($selection -eq "2") { $tz = "Central Standard Time" } 
elseif ($selection -eq "3") { $tz = "Central Europe Standard Time" }
elseif ($selection -eq "4") { $tz = "China Standard Time" } 

function Test-TimeInput {
    param(
        [string]$TimeInput
    )
    return $TimeInput -as [DateTime] -ne $null
}
do {
    $timeString = Read-Host -Prompt "Enter time to take the snapshot (HH:MM or HH:MM AM/PM)"
} until (Test-TimeInput -TimeInput $timeString)


function Test-Date {
    param (
        [string]$DateInput
    )
    return $DateInput -as [DateTime] -ne $null
}
do {
    $dateString = Read-Host -Prompt 'Enter date to take the snapshot (mm/dd/yyyy)'
} until (Test-Date -DateInput $dateString)


$inDT = "$dateString $timeString"
$outtz = [System.TimeZoneInfo]::GetSystemTimeZones() | Where-Object { $_.Id -eq "Eastern Standard Time" }
if ($tz -eq "Eastern Standard Time") {
    $outDT = [datetime]$inDT
} else {
    $intz = [System.TimeZoneInfo]::GetSystemTimeZones() | Where-Object { $_.Id -eq $tz }
    $outDT = [System.TimeZoneInfo]::ConvertTime($inDT, $intz, $outtz)
}

$createTime = [long](Get-Date -Date $outDT -UFormat %s)


$notifyEmail = read-host -prompt "Enter email addresses to notify once snapshot has been taken (sepearate multiple addresses with semicolon ';') Press ENTER to skip"
while ($notifyEmail.contains(",")) { $notifyEmail = read-host -prompt "Enter email addresses to notify once snapshot has been taken (sepearate multiple addresses with semicolon ';' DO NOT USE COMMAs ',') Press ENTER to skip." }

[int]$keepDays = read-host -prompt "Enter number of days to keep snapshot after it is taken. The snapshot will be automatically deleted after this time. Press ENTER to skip automatic deletion"

if ($keepDays) { 
    $keepDaysMSG "Snapshot will be deleted $keepDays days after creation." 
    
    $keepTime = $keepDays * 86400
    $removeTime = $createTime + $keepTime
    $removeFile = "/opt/scripts/vmware/activesnaps/$vm-$removeTime.csv"
    new-item $removeFile -ItemType File | Out-Null
    Invoke-Command{chmod 666 $removeFile}
    set-content $removeFile 'vCenter, VM, SnapName, Taken, Remove'
    add-content $removeFile "$foundvc, $vm, Insight-Scheduled-$removeTime, $currentTime, $removeTime"
} 
else { $keepDaysMSG "Snapshot WILL NOT be deleted automatically."}

$filename = "/opt/scripts/vmware/scheduledSnaps/$vm-$createTime.csv"
new-item $filename -ItemType File | Out-Null
Invoke-Command{chmod 666 $filename}
$currentTime = get-date -UFormat %s
set-content $filename 'vCenter, VM, SnapName, ScheduledTime, NotifyEmail'
add-content $filename "$foundvc, $vm, Insight-Scheduled-$removeTime, $createTime, $notifyEmail"

write-host "Snapshot has been scheduled successfully"
write-host "VM Name: $vm"
write-host "Scheduled for: $outDT $tz"
write-host $keepDaysMSG

$From = "Insight-Automations@duracell.com"
$Subject = "New Snapshot Scheduled - $vm"
$Body = @"
A VMWare Snapshot has been scheduled:

VM: $vm
Scheduled for: $outDT $tz
$keepDaysMSG
"@

$SMTPServer = "smtp.duracell.com"
$SMTPPort = "25"
if ($notifyEmail) { Send-MailMessage -From $From -to $notifyEmail -Subject $Subject -Body $Body -SmtpServer $SMTPServer -Port $SMTPPort -Attachments $outfile }
Send-MailMessage -From $From -to "michael.general@insight.com" -Subject $Subject -Body $Body -SmtpServer $SMTPServer -Port $SMTPPort -Attachments $outfile

