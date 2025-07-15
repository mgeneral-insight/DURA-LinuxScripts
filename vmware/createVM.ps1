param(
    $location,
    $servername,
    $memory,
    $cpus, 
    $ip,
    $cname,
    $disks
)

#$ErrorActionPreference = "SilentlyContinue"
[System.Net.Http.HttpClient]::DefaultProxy = New-Object System.Net.WebProxy($null)
$logo = get-content -raw /opt/scripts/linux/logo.txt
function intro {
    clear-host
    Write-Host $logo
    Write-Host "Welcome to the Duracell On-Site Server Build Environment."
    Write-Host "This script will deploy a VM at the chosen site."
    Write-Host "You will be prompted for the following information, please make sure you have this ready:"
    Write-Host "- Server Name (NOT THE CNAME)"
    Write-Host "- Location of Server"
    Write-Host "- Server Operating System"
    Write-Host "- Amount of Memory"
    Write-Host "- Number of CPUs"
    Write-Host "- Number of data disks and size"
    Read-Host "Press ENTER to continue..."
}
function getlocation {
    while ("BECT","LGGA","CVTN","FBGA","CHIL","CNNC","CNDG","HEI","AAR" -notcontains $location ) { 
        Clear-Host
        Write-Host $logo
        Write-Host "Choose location for new VM:"
        Write-Host "1) BECT - Bethel, CT"
        Write-Host "2) CVTN - Cleveland, TN"
        Write-Host "3) FBGA - Fairburn, GA"
        Write-Host "4) LGGA - LaGrange, GA"
        Write-Host "5) AAR - Aarschot, Belgium"
        Write-Host "6) HEI - Heist, Belgium"
        Write-Host "7) CNNC - Nanchang, China"
        Write-Host "8) CNDG - DongGuan, China"
        $loc_sel = Read-Host -Prompt "Select a location (1-9)" 
        switch($loc_sel) {
            '1' { $location = "BECT" }
            '2' { $location = "CVTN" }
            '3' { $location = "FBGA" }
            '4' { $location = "LGGA" }
            '5' { $location = "AAR" }
            '6' { $location = "HEI" }
            '7' { $location = "CNNC" }
            '8' { $location = "CNDG"}
        }
    }
    return $location
}

function getOS {
    while ("WS-2019","WS-2022","Linux-RH9","Linux-Ubuntu2204","WS-2025" -notcontains $os) {
        Clear-Host
        Write-Host $logo
        Write-Host "Choose OS for new VM:"
        Write-Host "1: Windows Server 2019 Datacenter"
        Write-Host "2: Windows Server 2022 Datacenter"
        Write-Host "3: Windows Server 2025 Datacenter"
        Write-Host "4: Redhat Server 9"
        Write-Host "5: Ubuntu Server 22.04"
        $os_sel = Read-Host -Prompt "Select OS (1-4)"
        switch($os_sel) {
            '1' { $os = "WS-2019" }
            '2' { $os = "WS-2022" }
            '3' { $os = "WS-2025"}
            '4' { $os = "Linux-RH9"}
            '5' { $os = "Linux-Ubuntu2204"}

        }
    }
    return $os
}

function getIP {
    Clear-Host
    Write-Host $logo
    Write-Host "Getting next available IP from Infoblox for $location..."
    $ibp = Get-Content '/opt/scripts/.credfiles/WIN04.cred' | ConvertTo-SecureString
    $ibcred = New-Object System.Management.Automation.PSCredential("InsightMSP-Win04",$ibp)
    $uri = "https://usalp-gminfo-01.duracell.com/wapi/v1.4.1/$NetRef`?_function=next_available_ip&num=1"
    $ipresult = Invoke-RestMethod -Uri $uri -Method Post -Credential $ibcred -SkipCertificateCheck
    $ip = $ipresult.ips
    if (!($ip)) { 
        Write-Host "Unable to retrieve next available IP from Infoblox."
        $ip = Read-Host -Prompt "Enter IP Address for new server"
    }
    else { 
        Write-Host "Received IP: $ip" 
        while ("n","y" -notcontains $ipq) { 
            $ipq = Read-Host -Prompt "Do you want to use this IP (y/n)"
            if ( $ipq -eq "n" ) { $ip = Read-Host -Prompt "Enter IP Address for new server" }
        }
    }

    return $ip
}

function validateIP {
    $initIP = $ip
    $pingIP = Test-Connection $ip -Count 1 -ErrorAction SilentlyContinue
    $nslookupIP = Resolve-DnsName -QueryType PTR $ip
    $ipRegEx="^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$"
    if ($ip -notmatch $ipRegEx) { Write-Host "ERROR: Invalid IP, Enter IP address for new server" -ForegroundColor Red; $script:ip = Read-Host }
    elseif ($pingIP.status -ne "TimedOut") { Write-Host "ERROR: IP address $ip responded to ping, enter a free IP address" -ForegroundColor Red; $script:ip = Read-Host }
    if ($nslookupIP.Answers) { Write-Host "ERROR: IP Address resolved to a record in DNS, Please enter a valid FREE IP address" -ForegroundColor Red; $script:ip = Read-Host }
    $finIP = $ip
    if ($initIP -ne $finIP) { return "Invalid" }
    else { return "Valid" }
}

function createDNS {
    $fqdn = $servername+".corp.duracell.com"
    $cfqdn = $cname+".corp.duracell.com"
    $ibp = Get-Content '/opt/scripts/.credfiles/WIN04.cred' | ConvertTo-SecureString
    $ibcred = New-Object System.Management.Automation.PSCredential("InsightMSP-Win04",$ibp)
    $auri = "https://usalp-gminfo-01.duracell.com/wapi/v1.4.1/record:a"
    $ptruri = "https://usalp-gminfo-01.duracell.com/wapi/v1.4.1/record:ptr"
    $cnameuri = "https://usalp-gminfo-01.duracell.com/wapi/v1.4.1/record:cname"
    $adata = @{
        ipv4addr = $ip
        name = $fqdn
    }
    $ajson = $adata | ConvertTo-Json
    $ptrdata = @{
        ptrdname = $fqdn
        ipv4addr = $ip
    }
    $ptrjson = $ptrdata | ConvertTo-Json
    Write-Host "Creating A DNS Record in Infoblox..."
    $ares = Invoke-RestMethod -Method Post -Credential $ibcred -SkipCertificateCheck -Uri $auri -Body $ajson -ContentType 'application/json'
    Write-Host "Creating PTR DNS Record in Infoblox..."    
    $ptrres = Invoke-RestMethod -Method Post -Credential $ibcred -SkipCertificateCheck -Uri $ptruri -Body $ptrjson -ContentType 'application/json'
    if ($cname) {
        $cnamedata = @{
            name = $cfqdn
            canonical = $fqdn
        }
        $cnamejson = $cnamedata | ConvertTo-Json
        Write-Host "Creating CNAME DNS Record in Infoblox..."
        $cnameres = Invoke-RestMethod -Method Post -Credential $ibcred -SkipCertificateCheck -Uri $cnameuri -Body $cnamejson -ContentType 'application/json'
    }
}

function confirm {
    Clear-Host
    Write-Host $logo
    Write-Host "Hostname : $servername"
    Write-Host "OS : $os"
    Write-Host "CNAME : $cname"
    Write-Host "Location : $location"
    Write-Host "CPUs : $cpus"
    Write-Host "Memory : $memory GB"
    Write-Host "IP : $ip"
    $disknum = 1
    foreach ( $disk in $disks ) {
        Write-Host "Data Disk $disknum : $disk GB"
        $disknum++
    }
    while ("y","n" -notcontains $deploy) { $deploy = Read-Host -Prompt "`r`nDo you want to deploy this VM (y/n)?" }
    if ($deploy -eq "n") { exit 1}
}
################ RUN ################
intro
# Get Servername
while (!($servername)) {
    Clear-Host
    get-content -raw /opt/scripts/linux/logo.txt
    $servername = Read-Host -Prompt "Enter hostname for new VM (NOT CNAME)"
}
$servername = $servername.ToUpper()

# Get OS
$os = getOS
if ($os -eq "WS-2019") {
    $template = "Template-WS2019"
    $customization = "Template-Server2019"
    $OSType = "Windows"
}
elseif ($os -eq "WS-2022") {
    $template = "Template-WS2022"
    $customization = "Template-Server2022"
    $OSType = "Windows"
}
elseif ($os -eq "WS-2025") {
    $template = "Template-WS2025"
    $customization = "Template-Server2025"
    $OSType = "Windows"
}
elseif ($os -eq "Linux-RH9") {
    $template = "Template-Redhat9"
    $customization = "Template-Linux"
    $OSType = "Linux"
}
elseif ($os -eq "Linux-Ubuntu2204") {
    $template = "Template-Ubuntu2204"
    $customization = "Template-Linux"
    $OSType = "Linux"
}



# Get Location
$location = getlocation

# Get Memory
Clear-Host
get-content -raw /opt/scripts/linux/logo.txt
while (!($memory -match '^[0-9]+$')) { $memory = Read-Host -Prompt "Enter amount of memory in GB" }

# Get CPUs
Clear-Host
get-content -raw /opt/scripts/linux/logo.txt
while (!($cpus -match '^[0-9]+$')) { $cpus = Read-Host -Prompt "Enter number of CPUs" }

# Get Disks
Clear-Host
get-content -raw /opt/scripts/linux/logo.txt
if (!($disks)) {
    $disks = @()
    while ("y","n" -notcontains $moredisks) { $moredisks = Read-Host -Prompt "Do you need to add additional disks to the VM (y/n)" }
    while ($moredisks -eq "y") {
        $diskplus = Read-Host -Prompt "Enter size in GB of disk"
        while (!($diskplus -match '^[0-9]+$')) { $diskplus = Read-Host -Prompt "Invalid size, enter size in GB for additional disk" }
        $disks += $diskplus
        $moredisks = Read-Host -Prompt "Do you need to add additional disks to the VM (y/n)" 
        while ("y","n" -notcontains $moredisks) { $moredisks = Read-Host -Prompt "Do you need to add additional disks to the VM (y/n)" }
    }
}
# Get Location Information
$securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
$credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
#Write-Host "Connecting to vCenter..."
if (($location -eq "CVTN") -or ($location -eq "BECT") -or ($location -eq "LGGA") -or ($location -eq "FBGA")) { 
    $vcenter = "becn-wvvctrp03.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    if ( $location -eq "CVTN" ) {
        $cluster = Get-Cluster 'Cleveland_Plant'
        $datastore = Get-Datastore 'VxRail-Virtual-SAN-Datastore-7c4bd65f-502b-46cf-a985-e1b8f3223314'
        $portgroup = Get-VirtualPortGroup -Id 'DistributedVirtualPortgroup-dvportgroup-134990'
        $NetRef = "network/ZG5zLm5ldHdvcmskMTAuMTYuNTAuMC8yMy8w:10.16.50.0/23/default"
        $dgw = "10.16.50.1"
        $dns = '("10.151.16.175","10.151.24.175","10.6.100.175")'
    }
    elseif ( $location -eq "BECT") {
        $cluster = Get-Cluster 'Bethel'
        $datastore = Get-Datastore 'BECT-vsanDatastore'
        $vmhost = Get-VMHost -Name bect-esxi001.corp.duracell.com
        $portgroup = Get-VirtualPortGroup -id 'DistributedVirtualPortgroup-dvportgroup-265286'
        $NetRef = "network/ZG5zLm5ldHdvcmskMTAuMzIuNTAuMC8yMy8w:10.32.50.0/23/default"
        $dgw = "10.32.50.1"
        $dns = '("10.32.50.175","10.151.24.175","10.6.100.175")'
    }
    elseif ( $location -eq "LGGA" ) {
        $cluster = Get-Cluster 'LaGrange Plant'
        $datastore = Get-Datastore 'VxRail-Virtual-SAN-Datastore-7908d34e-5840-4b2b-a7aa-f6d5a31b4304'
        $portgroup = Get-VirtualPortGroup -Id 'DistributedVirtualPortgroup-dvportgroup-105507'
        $NetRef = "network/ZG5zLm5ldHdvcmskMTAuMjQuNTAuMC8yMy8w:10.24.50.0/23/default"
        $dgw = "10.24.50.1"
        $dns = '("10.151.24.175","10.151.41.175","10.6.100.175")'
    }
    elseif ( $location -eq "FBGA" ) {
        $cluster = Get-Cluster 'North Atlanta'
        $datastore = Get-Datastore 'NATL-VXRail-VSAN'
        $vmhost = Get-VMHost -Name fbga-esxi101.corp.duracell.com
        $portgroup =  Get-VirtualPortGroup -id 'DistributedVirtualPortgroup-dvportgroup-275291'
        $NetRef = "network/ZG5zLm5ldHdvcmskMTAuNDEuNTAuMC8yMy8w:10.41.50.0/23/default"
        $dgw = "10.41.50.1"
        $dns = '("10.151.41.175","10.151.24.175","10.6.100.175")'
    }
}
elseif ($location -eq "CNNC") { 
    $vcenter = "cnnc-winvc01.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $cluster = get-cluster 'Nanchang Prod'
    $datastore = Get-Datastore 'CNNC-vsanDatastore'
    $vmhost =  Get-VMHost -Name 'cnnc-esx001.corp.duracell.com'
    $portgroup = Get-VirtualPortGroup -id 'DistributedVirtualPortgroup-dvportgroup-36122'
    $NetRef = "network/ZG5zLm5ldHdvcmskMTAuNzIuNTAuMC8yMy8w:10.72.50.0/23/default"
    $dgw = "10.72.50.1" 
    $dns = '("10.151.72.175","10.151.71.175","10.6.100.175")'
}
elseif ($location -eq "CNDG") { 
    $vcenter = "dgwinvc03.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $cluster = Get-Cluster 'DCL Prod'
    $datastore = get-datastore 'VxRail-Virtual-SAN-Datastore-9216335a-10f0-450a-ac45-3dfa32d7943f'
    $portgroup = Get-VirtualPortGroup -Id 'DistributedVirtualPortgroup-dvportgroup-24244'
    $NetRef = "network/ZG5zLm5ldHdvcmskMTAuNzEuNTAuMC8yMy8w:10.71.50.0/23/default"
    $dgw = "10.71.50.1"
    $dns = '("10.151.71.175","10.151.72.175","10.6.100.175")'
}
elseif ($location -eq "AAR") {
    $vcenter = "aar-winvc04.corp.duracell.com"
    $connect = connect-viserver -server $vcenter -credential $credentials
    $cluster = Get-Cluster 'AAR VxRail Cluster'
    $datastore = Get-Datastore 'AAR VxRail vSAN'
    $portgroup = Get-VirtualPortGroup -id 'DistributedVirtualPortgroup-dvportgroup-3010'
    $NetRef = "network/ZG5zLm5ldHdvcmskMTAuNTAuNTAuMC8yMy8w:10.50.50.0/23/default"
    $dgw = "10.50.50.1"
    $dns = '("10.151.50.175","10.151.54.175","10.6.100.175")'
}
elseif ($location -eq "HEI") { 
    $securePassword = Get-Content '/opt/scripts/.credfiles/hei.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@heist.local", $securePassword)
    $vcenter = "heivcsa.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $cluster = Get-Cluster 'Heist_Cluster'
    $datastore = Get-Datastore 'HEI-VXRail-VSan'
    $portgroup = Get-VirtualPortGroup -id 'DistributedVirtualPortgroup-dvportgroup-69158'
    $NetRef = "network/ZG5zLm5ldHdvcmskMTAuNTQuNTAuMC8yMy8w:10.54.50.0/23/default"
    $dgw = "10.54.50.1"
    $dns = '("10.151.54.175","10.151.50.175","10.6.100.175")'
}

# Get IP
Clear-Host
if (!($ip)) { $ip = getIP }
while ($validIP -ne "Valid") { $validIP = validateIP }

# Get CName
if (!($cname)) { 
    while ("y","n" -notcontains $cnameq) { $cnameq = Read-Host -Prompt "Does this server require a CNAME (y/n)"}
    if ($cnameq -eq "y") { $cname = Read-Host -Prompt "Enter CNAME for $servername" }
}

# Confirm VM Details
confirm

# Deploy VM
$clItem = Get-ContentLibraryItem -Name $template -ContentLibrary $location
$custos = Get-OSCustomizationSpec $customization
Write-Host "Deploying VM..."
New-VM -ContentLibraryItem $clItem -name $servername -ResourcePool $cluster -Datastore $datastore -DiskStorageFormat thin -WarningAction SilentlyContinue | Out-Null
$vm = get-vm $servername
if (!($vm)) { Write-Host "ERROR: Can not validate deployment of VM" -ForegroundColor Red | Read-Host "Verify VM creation, press ENTER to continue or CTRL+C to exit"}
Write-Host "Configuring VM..."
$vm | Set-Vm -OSCustomizationSpec $custos -NumCpu $cpus -MemoryGB $memory -confirm:$false | Out-Null
$vm | Get-NetworkAdapter | Set-NetworkAdapter -StartConnected $true -confirm:$false | Out-Null
$vm | Get-NetworkAdapter | Set-NetworkAdapter -Portgroup $portgroup -WarningAction SilentlyContinue -confirm:$false | Out-Null
$currdate = (get-date).ToShortDateString()
$newnote = "Created by Insight Automated VM Deployment Tool on $currdate"
$vm | Set-VM -Notes $newnote -Confirm:$false | Out-Null
foreach ($disk in $disks) {
    $vm | New-HardDisk -CapacityGB $disk -StorageFormat Thin | Out-Null
}

# Set tools auto-update
Write-Host "Setting VMware Tools Auto-Update..."
$Toolsconfig = New-Object VMware.Vim.VirtualMachineConfigSpec
$Toolsconfig.tools = New-Object VMware.Vim.ToolsConfigInfo
$Toolsconfig.tools.toolsUpgradePolicy = "upgradeAtPowerCycle"
(Get-VM $servername | Get-View).ReconfigVM($Toolsconfig) | Out-Null

# Power on VM
Write-Host "Powering on VM..."
Start-VM $servername -confirm:$false | Out-Null
#Start-Sleep -Seconds 15
#while ($vm.PowerState -ne "PoweredOn") { Write-Host "ERROR: Could not verify VM Powered On Successfully, Check the VM is powered on, will recheck in 10s..." -ForegroundColor Red; Start-Sleep -Seconds 10 }

# Wait for customization to complete.
Write-Host "Waiting for OS customization to complete (this can take 5-10 mins)..."
DO {(Get-VMGuest $servername).HostName | Out-Null}
While (((Get-VMGuest $servername).HostName) -Ne "$servername")

# Check VMtools Running
$VMTool = $vm | Select-Object -ExpandProperty ExtensionData | Select-Object -ExpandProperty guest
$VMToolStatus = $VMTool.ToolsRunningStatus
Start-Sleep -Seconds 5
Do {Write-host "Waiting on VMWare Tools to start on VM..."; Start-Sleep -Seconds 5}
Until ($VMToolStatus -eq "guestToolsRunning")
Write-Host "VMWare Tools started on VM"
# Set IP Address
Write-Host "Setting VM IP address..."
if ( $OSType -eq "Windows" ) {
    $templatep = Get-Content '/opt/scripts/.credfiles/TEMPLATE.cred' | ConvertTo-SecureString
    $templatecred = New-Object System.Management.Automation.PSCredential("localadmin",$templatep)
$IPScript = @'
`$GetAdapter = Get-NetAdapter
`$GetAdapter | New-NetIPAddress -AddressFamily IPv4 -IPAddress $ip -PrefixLength 23 -DefaultGateway $dgw
`$GetAdapter | Set-DnsClientServerAddress -ServerAddresses $dns
Start-Sleep -seconds 5
`$GetAdapter | Set-NetConnectionProfile -NetworkCategory Private
Start-Sleep -seconds 5
Set-NetFirewallProfile -Enabled False
Start-Sleep -seconds 5
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -Value 1
'@
    $vm | Invoke-VMScript -ScriptType Powershell -ScriptText ($ExecutionContext.InvokeCommand.ExpandString($IPScript)) -GuestCredential $templatecred | Out-Null

} elseif ( $OSType -eq "Linux" ) {
    $rootp = Get-Content '/opt/scripts/.credfiles/linuxroot.cred' | ConvertTo-SecureString
    $templatecred = New-Object System.Management.Automation.PSCredential("root",$rootp)

    if ( $os -eq "Linux-RH9") {
        $IPScript1 = "nmcli con delete `$(nmcli -t -f UUID,DEVICE con show | awk -F`":`" '{if (`$2 == `"`") print `$1}')"
        $vm | Invoke-VMScript -ScriptType Bash -ScriptText $IPScript1 -GuestCredential $templatecred | Out-Null

        $dns = $dns.Replace("(", "")
        $dns = $dns.Replace(")", "")
        $IPScript2 = "nmcli connection modify ens192 ipv4.method manual ipv4.addresses $ip/23 ipv4.gateway $dgw ipv4.dns $dns ipv4.dns-search corp.duracell.com"
        $vm | Invoke-VMScript -ScriptType Bash -ScriptText $IPScript2 -GuestCredential $templatecred | Out-Null

        $IPScript3 = "nmcli con up ens192"
        $vm | Invoke-VMScript -ScriptType Bash -ScriptText $IPScript3 -GuestCredential $templatecred | Out-Null
    } elseif ( $os -eq "Linux-Ubuntu2204") {
        $dns = $dns.Replace("(", "")
        $dns = $dns.Replace(")", "")
        $dnsarr=$dns.split(",").replace("`"","")
        $dns1=$dnsarr[0]
        $dns2=$dnsarr[1]
        $dns3=$dnsarr[2]
        $IPScript1 = "
                sed -i 's/IPA/$ip/g' /root/00-Install.yaml
                sed -i 's/GWY/$dgw/g' /root/00-Install.yaml
                sed -i 's/DNS1/$dns1/g' /root/00-Install.yaml
                sed -i 's/DNS2/$dns2/g' /root/00-Install.yaml
                sed -i 's/DNS3/$dns3/g' /root/00-Install.yaml
                rm -r /etc/netplan/*
                cp /root/00-Install.yaml /etc/netplan/
                netplan apply
        "
        $vm | Invoke-VMScript -ScriptType Bash -ScriptText $IPScript1 -GuestCredential $templatecred 



    }
}

### Check if IP set correctly
Write-Host "Waiting for IP to be set in VM..."
Do {(Get-VMGuest $servername).IPADDRESS[0] | Out-Null}
While (((Get-VMGuest $servername).IPADDRESS)[0] -Ne "$ip")

# Create DNS entries
createDNS


# Reboot Server
Write-Host "Rebooting Server..."
$vm | Restart-VMGuest -Confirm:$false | Out-Null

# Check VMware Tools
Start-Sleep -Seconds 30
$VMTool = $vm | Select-Object -ExpandProperty ExtensionData | Select-Object -ExpandProperty guest
$VMToolStatus = $VMTool.ToolsRunningStatus
Do {Start-Sleep -Seconds 10}
Until ($VMToolStatus -eq "guestToolsRunning")
Write-Host "...server has rebooted and is back up."

if ( $OSType -eq "Windows" ) {
    Write-Host "This script has completed, to finish configuring the VM follow steps in KB0074565"
} elseif ( $OSType -eq "Linux" ) {
    Write-Host "This script has completed, to finish configuring the VM follow steps in KB#######"
}
