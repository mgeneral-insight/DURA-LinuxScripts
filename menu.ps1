clear-host
get-content -raw /opt/scripts/linux/logo.txt

Write-Host @"
Select a task to perform:

1) Create a Snapshot of a VM
2) Schedule a Snapshot of a VM
3) Get Next Available IP 
4) Create DNS Entries in Infoblox
5) Create New VMware VM
6) Get Vulnerability Report from Qualys

"@

Do { $selection = Read-Host "Choose an option (1-6)" }
Until (1..6 -contains $selection)

if ($selection -eq "1") { pwsh /opt/scripts/linux/vmware/createSnapshot.ps1 } 
elseif ($selection -eq "2") { pwsh /opt/scripts/linux/vmware/scheduleSnapshot.ps1 } 
elseif ($selection -eq "3") { pwsh /opt/scripts/linux/getIP.ps1 }
elseif ($selection -eq "4") { pwsh /opt/scripts/linux/createDNS.ps1 } 
elseif ($selection -eq "5") { pwsh /opt/scripts/linux/vmware/createVM.ps1 } 
elseif ($selection -eq "6") { pwsh /opt/scripts/linux/qualys/qualysReport.ps1}