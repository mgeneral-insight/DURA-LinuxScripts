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
3) Central EUROPEAN Time Zone - CET/CEST - (EU)
4) China Standard Time Zone - (APAC)
---------------------------------------------
"@
read-host -Prompt "Enter Time Zone for time to take snapshot"