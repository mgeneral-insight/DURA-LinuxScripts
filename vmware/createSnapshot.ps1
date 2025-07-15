param ($vm)

$ErrorActionPreference = "SilentlyContinue"
[System.Net.Http.HttpClient]::DefaultProxy = New-Object System.Net.WebProxy($null)
$keepDays = 5
$vcenters = @("aar-winvc04.corp.duracell.com", "becn-wvvctrp03.corp.duracell.com", "cnnc-winvc01.corp.duracell.com", "dgwinvc03.corp.duracell.com", "heivcsa.corp.duracell.com")


function findVM {
    param ($vctr)
    if ( $vctr -eq 'heivcsa.corp.duracell.com' ) {
        $securePassword = Get-Content '/opt/scripts/.credfiles/hei.cred' | ConvertTo-SecureString
        $credentials = New-Object System.Management.Automation.PSCredential ("administrator@heist.local", $securePassword)
    } else {
        $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
        $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
    }
    $conn = connect-viserver -server $vctr -credential $credentials
    $getvm = get-vm $vm
    disconnect-viserver * -Confirm:$false
    if ($getvm) {
        $script:foundvc = $vctr
        break
    }
}
clear-host
get-content -raw /opt/scripts/linux/logo.txt
Write-Host "This script will take a snapshot of a specified VM and will automatically delete the snapshot after $keepDays days."
write-host ""

if (!($vm)) { $vm = Read-Host "Enter the name of the VM to snapshot" }
Write-Host "Searching vCenters for VM $vm..."
foreach ($vcenter in $vcenters) {
    findVM -vctr $vcenter
}
if ( $null -eq $foundvc ) {
    Write-Host "Virtual Machine $vm was not found on any vCenter. Check the VM name and make sure it is a VMware Virtual Machine."
    Read-Host "Press ENTER to Exit..."
    Exit 1
}

Write-Host "$vm found on $foundvc"
Write-Host "Taking snapshot of $vm"

if ( $foundvc -eq 'heivcsa.corp.duracell.com' ) {
    $securePassword = Get-Content '/opt/scripts/.credfiles/hei.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@heist.local", $securePassword)
} else {
    $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
}

[int]$currentTime = Get-Date -UFormat %s
$keepTime = $keepDays * 86400 
$removeTime = $currentTime + $keepTime
$filename = "/opt/scripts/.activeSnaps/$vm-$currentTime.csv"
new-item $filename -ItemType File | Out-Null
Invoke-Command{chmod 666 $filename}
$snapname = "Insight-$currentTime"
set-content $filename 'vCenter, VM, SnapName, Taken, Remove'
add-content $filename "$foundvc, $vm, $snapname, $currentTime, $removeTime"

$conn1 = connect-viserver -server $foundvc -credential $credentials
$createsnap = new-snapshot -vm $vm -name $snapname -confirm:$false
$checksnap = get-vm $vm | get-snapshot -name $snapname
if ($null -eq $checksnap) {
    Write-Host "ERROR: Snapshot not able to be validated."
} else {
    Write-Host "Success: Snapshot verified."
    Write-Host "Snapshot Name: $snapname"
}

$disconn = disconnect-viserver * -Confirm:$false