param (
    [switch]$batch=$false,
    $vm
)

if ( $batch -eq $true ) {
    Write-Host "Batch Mode!"
    if ( $null -eq $vm ) {
        Write-Host "ERROR: Must Supply -vm <vm name> when in batch mode"
        exit 1
    }
}

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

Write-Host "This program will take a snapshot of a specified VM and will automatically delete the Snapshot after 96 hours."
#if ( $batch -ne $true ) { Write-Host "Enter the name of the VM to snapshot:" }
#Write-Host
if ( $batch -ne $true ) { $vm = Read-Host "Enter the name of the VM to snapshot" }

Write-Host "`n `nSearching vCenters for VM $vm..."

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

Write-Host "$vm found on $foundvc"
Write-Host "Taking snapshot of $vm"

if ( $foundvc -eq 'heivcsa.corp.duracell.com' ) {
    $securePassword = Get-Content '/opt/scripts/vmware/hei.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@heist.local", $securePassword)
} else {
    $securePassword = Get-Content '/opt/scripts/vmware/vctr.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
}


$datecode = Get-Date -UFormat %s
$snapname = "Insight-" +$datecode
$filename = "/opt/scripts/vmware/activesnaps/" +$datecode +".csv"
new-item $filename -ItemType File | Out-Null
Invoke-Command{chmod 666 $filename}
set-content $filename 'vCenter, VM, SnapName'
add-content $filename "$foundvc, $vm, $snapname"


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

if ( $batch -ne $true ) {
    read-Host 'Press ENTER to exit...';
}
