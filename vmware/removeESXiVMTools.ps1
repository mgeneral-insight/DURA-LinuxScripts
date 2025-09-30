[System.Net.Http.HttpClient]::DefaultProxy = New-Object System.Net.WebProxy($null)
$logo = get-content -raw /opt/scripts/linux/logo.txt
write-host "This script will remove the VMware Tools VIB from all hosts in the chosen cluster"
write-host "Select a cluster from the list below:"
$clusters = @("Bethel","Cleveland","LaGrange","Fairburn","Aarschot","Heist","DongGuan","Nanchang")
$i = 0
foreach ($cluster in $clusters) {
    write-host "$i - $cluster"
    $i++
}
$j = $i - 1
$clusterNum = read-host "Enter number (0-$j) for number of cluster."

write-host "Processing cluster" $clusters[$clusterNum]
if ($clusterNum -eq "0") {
    # Bethel
    $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
    $vcenter = "becn-wvvctrp03.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $clust = Get-Cluster -Name Bethel
    $hosts = $clust | get-vmhost
} elseif ($clusterNum -eq "1") {
    # Cleveland
    $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
    $vcenter = "becn-wvvctrp03.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $clust = Get-Cluster -Name "Cleveland_Plant"
    $hosts = $clust | get-vmhost
} elseif ($clusterNum -eq "2") {
    # LaGrange
    $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
    $vcenter = "becn-wvvctrp03.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $clust = Get-Cluster -Name "LaGrange Plant"
    $hosts = $clust | get-vmhost
} elseif ($clusterNum -eq "3") {
    # Fairburn
    $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
    $vcenter = "becn-wvvctrp03.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $clust = Get-Cluster -Name "North Atlanta"
    $hosts = $clust | get-vmhost
} elseif ($clusterNum -eq "4") {
    # Aarschot
    $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
    $vcenter = "aar-winvc04.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $hosts = get-vmhost
} elseif ($clusterNum -eq "5") {
    # Heist
    $securePassword = Get-Content '/opt/scripts/.credfiles/hei.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@heist.local", $securePassword)
    $vcenter = "heivcsa.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $hosts = get-vmhost
} elseif ($clusterNum -eq "6") {
    # DongGuan
    $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
    $vcenter = "dgwinvc03.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $hosts = get-vmhost
} elseif ($clusterNum -eq "7") {
    # Nanchang
    $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
    $vcenter = "cnnc-winvc01.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $hosts = get-vmhost
}

foreach ($vmhost in $hosts) {
    write-host "Starting Host : $vmhost"
    ##### Check for tools-light VIB 
    $esxcli = get-esxcli -vmhost $vmhost -V2
    $esxcliArgs = $esxcli.software.vib.remove.createargs()
    $esxcliArgs.vibname = "tools-light"
    $action = $esxcli.software.vib.remove.invoke($esxcliArgs)
    if ($action.Message -eq "Operation finished successfully.") { 
            Write-Host "VIB removed successfully!" -ForegroundColor Green 
    } else {
            write-host "ERROR: VIB Removal Failed" -ForegroundColor Red
    }
}
Disconnect-VIServer -Confirm:$false