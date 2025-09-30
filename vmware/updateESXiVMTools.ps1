[System.Net.Http.HttpClient]::DefaultProxy = New-Object System.Net.WebProxy($null)
$logo = get-content -raw /opt/scripts/linux/logo.txt
clear-host
Write-Host $logo
Write-Host @"
This script will do the following:
Connect to Selected Cluster
Get a list of all ESXi hosts
On Each ESXi Host:
- Upload the VMware Tools VIB file to the vSAN Datastore
- Install the VIB file on the ESXi host
- Verify the VIB installed successfully
-------------------------------------------------------------
"@

$sourceFile = get-item /opt/.vmtools_vibs/latest/*
if ($sourcefile.count -ne 1) { 
    write-host "ERROR: Source VIB File not found or more than one file in Latest Directory /opt/.vmtools_vibs/latest" -foregroundcolor red
#    exit 1
}
$sourceFileName = $sourceFile.name

### Choose Cluster
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
    $datastore = get-datastore -name "BECT-vsanDatastore"
    $clust = Get-Cluster -Name Bethel
    $vmhosts = $clust | get-vmhost
} elseif ($clusterNum -eq "1") {
    # Cleveland
    $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
    $vcenter = "becn-wvvctrp03.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $datastore = get-datastore -name "VxRail-Virtual-SAN-Datastore-7c4bd65f-502b-46cf-a985-e1b8f3223314"
    $clust = Get-Cluster -Name "Cleveland_Plant"
    $vmhosts = $clust | get-vmhost
} elseif ($clusterNum -eq "2") {
    # LaGrange
    $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
    $vcenter = "becn-wvvctrp03.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $datastore = get-datastore -name "VxRail-Virtual-SAN-Datastore-7908d34e-5840-4b2b-a7aa-f6d5a31b4304"
    $clust = Get-Cluster -Name "LaGrange Plant"
    $vmhosts = $clust | get-vmhost
} elseif ($clusterNum -eq "3") {
    # Fairburn
    $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
    $vcenter = "becn-wvvctrp03.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $datastore = get-datastore -name "NATL-VXRail-VSAN"
    $clust = Get-Cluster -Name "North Atlanta"
    $vmhosts = $clust | get-vmhost
} elseif ($clusterNum -eq "4") {
    # Aarschot
    $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
    $vcenter = "aar-winvc04.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $datastore = get-datastore -name "AAR VxRail vSAN"
    $vmhosts = get-vmhost
} elseif ($clusterNum -eq "5") {
    # Heist
    $securePassword = Get-Content '/opt/scripts/.credfiles/hei.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@heist.local", $securePassword)
    $vcenter = "heivcsa.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $datastore = get-datastore -name "HEI-VXRail-VSan"
    $vmhosts = get-vmhost
} elseif ($clusterNum -eq "6") {
    # DongGuan
    $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
    $vcenter = "dgwinvc03.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $datastore = get-datastore -name "VxRail-Virtual-SAN-Datastore-9216335a-10f0-450a-ac45-3dfa32d7943f"
    $vmhosts = get-vmhost
} elseif ($clusterNum -eq "7") {
    # Nanchang
    $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
    $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
    $vcenter = "cnnc-winvc01.corp.duracell.com" 
    $connect = connect-viserver -server $vcenter -credential $credentials
    $datastore = get-datastore -name "CNNC-vsanDatastore"
    $vmhosts = get-vmhost
}




write-host "Copying VIB file to Datastore"
$datastore | new-psdrive -name DS -PSProvider VimDatastore -Root "\"
if (!(Test-Path -Path DS:/ISOs)) { new-item -path DS:/ISOs -ItemType directory }
if (!(Test-Path -Path DS:/ISOs/vmtools_vibs)) { new-item -path DS:/ISOs/vmtools_vibs -ItemType directory }

### Check for any existing files in VIBs folder
$existingFile = get-item DS:/ISOs/vmtools_vibs/*.zip
if ($existingFile) {
    ### Check name of source vs destination
    if ($existingFile.name -ne $sourceFile.name) {
        ### Delete old VIBs out of VIBs folder
        Remove-Item DS:/ISOs/vmtools_vibs/*.zip
        Copy-DatastoreItem -Item $sourcefile -Destination DS:/ISOs/vmtools_vibs/$sourceFileName
    } else {
        write-host "WARN : Current VIB file already exists on Datastore" -foregroundcolor Yellow
    }
} else {
    Copy-DatastoreItem -Item $sourcefile -Destination DS:/ISOs/vmtools_vibs/$sourceFileName
}

if (get-item DS:/ISOs/vmtools_vibs/$sourceFileName) {
    write-host "VIB file successfully copied to datastore." -foregroundcolor green
} else {
    write-host "ERROR: VIB File was not copied to datastore" -foregroundcolor red
    break
}
Remove-PSDrive -Name DS -Confirm:$false
$vibPath = "/vmfs/volumes/$datastore/ISOs/vmtools_vibs/$sourceFileName"


#$vmhosts | ft
foreach ($vmhost in $vmhosts) {
    write-host "-- Starting Host : $vmhost"
    $esxcli = get-esxcli -vmhost $vmhost -V2
    $esxcliCVargs = $esxcli.software.component.get.createargs()
    $esxcliCVargs.component = "VMware-VM-Tools"
    $esxcliCVresult = $esxcli.software.component.get.invoke($esxcliCVargs)
    $currentVersion = $esxcliCVresult.Version
    write-host "-- Current VMTools on Host: $currentVersion"
    ##### Check for current tools-light VIB
    $esxclipkgargs = $esxcli.software.vib.get.createargs()
    $esxclipkgargs.depot = $vibPath
    $esxclipkg = $esxcli.software.sources.vib.get.invoke($esxclipkgargs)
    $newVersion = $esxclipkg.Version
    #$esxcliargs = $esxcli.software.vib.list.createargs()
    #$esxcliargs.vibname = "tools-light"
    #$esxcliresult = $esxcli.software.vib.get.invoke($esxcliargs)
    #$currentVersion = $esxcliresult

    if ($currentVersion -ne $newVersion) {
        write-host "-- Starting install of VIB..."
        $esxcliArgs = $esxcli.software.vib.install.createargs()
        $esxcliArgs.depot = $vibPath
        $esxcliArgs.nosigcheck = $true
        $action = $esxcli.software.vib.install.invoke($esxcliArgs)
        if ($action.Message -eq "Operation finished successfully.") { 
            Write-Host "-- VIB installed successfully!" -ForegroundColor Green 
        } else {
            write-host "-- ERROR: VIB Installation Failed" -ForegroundColor Red
        }
    } else {
        write-host "-- VMware Tools VIB Version $currentVersion installed, skipping." -foregroundcolor Yellow
    } 
}

Disconnect-VIServer -Confirm:$false




<#
write-host "Starting vCenter : North America"
$securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
$credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
$vcenter = "becn-wvvctrp03.corp.duracell.com" 
$connect = connect-viserver -server $vcenter -credential $credentials

$clusters = get-cluster
foreach ($cluster in $clusters) {
    if ($cluster.name -eq "Cleveland_Plant") {
        $datastore = get-datastore -name "VxRail-Virtual-SAN-Datastore-7c4bd65f-502b-46cf-a985-e1b8f3223314"
        write-host " - Starting Cluster : Cleveland "
    } elseif ($cluster.name -eq "LaGrange Plant") {
        $datastore = get-datastore -name "VxRail-Virtual-SAN-Datastore-7908d34e-5840-4b2b-a7aa-f6d5a31b4304"
        write-host " - Starting Cluster : LaGrange"
    } elseif ($cluster.name -eq "North Atlanta") {
        $datastore = get-datastore -name "NATL-VXRail-VSAN"
        write-host " - Starting Fairburn Cluster..."
    } elseif ($cluster.name -eq "Bethel") {
        $datastore = get-datastore -name "BECT-vsanDatastore"
        write-host " - Starting Cluster : Bethel"
    }

    write-host "   Copying VIB file to Datastore"
    $datastore | new-psdrive -name DS -PSProvider VimDatastore -Root "\"
    if (!(Test-Path -Path DS:/ISOs)) {
        new-item -path DS:/ISOs -ItemType directory
    }
    if (!(Test-Path -Path DS:/ISOs/vmtools_vibs)) {
        new-item -path DS:/ISOs/vmtools_vibs -ItemType directory
    }

    ### Check for any existing files in VIBs folder
    $existingFile = get-item DS:/ISOs/vmtools_vibs/*.zip
    if ($existingFile) {
        ### Check name of source vs destination
        if ($existingFile.name -ne $sourceFile.name) {
            ### Delete old VIBs out of VIBs folder
            Remove-Item DS:/ISOs/vmtools_vibs/*.zip
            Copy-DatastoreItem -Item $sourcefile -Destination DS:/ISOs/vmtools_vibs/$sourceFileName
        } else {
            write-host "   WARN : Current VIB file already exists on Datastore" -foregroundcolor Yellow
        }
    } else {
        Copy-DatastoreItem -Item $sourcefile -Destination DS:/ISOs/vmtools_vibs/$sourceFileName
    }

    if (get-item DS:/ISOs/vmtools_vibs/$sourceFileName) {
        write-host "   VIB file successfully copied to datastore." -foregroundcolor green
    } else {
        write-host "   ERROR: VIB File was not copied to datastore" -foregroundcolor red
        break
    }
    Remove-PSDrive -Name DS -Confirm:$false
    $vibPath = "/vmfs/volumes/$datastore/ISOs/vmtools_vibs/$sourceFileName"
    $vmhosts = $cluster | get-vmhost
    foreach ($vmhost in $vmhosts) {
        write-host "   -- Starting Host : $vmhost"
        $esxcli = get-esxcli -vmhost $vmhost -V2
        $esxcliArgs = $esxcli.software.vib.install.createargs()
        $esxcliArgs.depot = $vibPath
        $esxcliArgs.nosigcheck = $true
        $action = $esxcli.software.vib.install.invoke($esxcliArgs)
        if ($action.Message -eq "Operation finished successfully.") { 
            Write-Host "      VIB installed successfully!" -ForegroundColor Green 
        } else {
            write-host "     ERROR: VIB Installation Failed" -ForegroundColor Red
        }
    }
}

Disconnect-VIServer -Confirm:$false

$stdVctrs = @("aar-winvc04.corp.duracell.com", "cnnc-winvc01.corp.duracell.com", "dgwinvc03.corp.duracell.com", "heivcsa.corp.duracell.com")
foreach ($vCenter in $stdVctrs) {
    write-host "Starting vCenter : $vCenter"
    if ($vCenter -eq "aar-winvc04.corp.duracell.com") {
        $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
        $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
        $connect = connect-viserver -server $vcenter -credential $credentials
        $datastore = get-datastore -name "AAR VxRail vSAN"
    } elseif ($vCenter -eq "cnnc-winvc01.corp.duracell.com") {
        $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
        $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
        $connect = connect-viserver -server $vcenter -credential $credentials
        $datastore = get-datastore -name "CNNC-vsanDatastore"
    } elseif ($vCenter -eq "dgwinvc03.corp.duracell.com") {
        $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
        $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
        $connect = connect-viserver -server $vcenter -credential $credentials
        $datastore = get-datastore -name "VxRail-Virtual-SAN-Datastore-9216335a-10f0-450a-ac45-3dfa32d7943f"
    } elseif ($vCenter -eq "heivcsa.corp.duracell.com") {
        $securePassword = Get-Content '/opt/scripts/.credfiles/hei.cred' | ConvertTo-SecureString
        $credentials = New-Object System.Management.Automation.PSCredential ("administrator@heist.local", $securePassword)
        $connect = connect-viserver -server $vcenter -credential $credentials
        $datastore = get-datastore -name "HEI-VXRail-VSan"
    }

    write-host "   Copying VIB file to Datastore"
    $datastore | new-psdrive -name DS -PSProvider VimDatastore -Root "\"
    if (!(Test-Path -Path DS:/ISOs)) {
        new-item -path DS:/ISOs -ItemType directory
    }
    if (!(Test-Path -Path DS:/ISOs/vmtools_vibs)) {
        new-item -path DS:/ISOs/vmtools_vibs -ItemType directory
    }

    ### Check for any existing files in VIBs folder
    $existingFile = get-item DS:/ISOs/vmtools_vibs/*.zip
    if ($existingFile) {
        ### Check name of source vs destination
        if ($existingFile.name -ne $sourceFile.name) {
            ### Delete old VIBs out of VIBs folder
            Remove-Item DS:/ISOs/vmtools_vibs/*.zip
            Copy-DatastoreItem -Item $sourcefile -Destination DS:/ISOs/vmtools_vibs/$sourceFileName
        } else {
            write-host "   WARN : Current VIB file already exists on Datastore" -foregroundcolor Yellow
        }
    } else {
        Copy-DatastoreItem -Item $sourcefile -Destination DS:/ISOs/vmtools_vibs/$sourceFileName
    }

    if (get-item DS:/ISOs/vmtools_vibs/$sourceFileName) {
        write-host "   VIB file successfully copied to datastore." -foregroundcolor green
    } else {
        write-host "   ERROR: VIB File was not copied to datastore" -foregroundcolor red
        break
    }
    Remove-PSDrive -Name DS -Confirm:$false
    $vibPath = "/vmfs/volumes/$datastore/ISOs/vmtools_vibs/$sourceFileName"
    $vmhosts = get-vmhost
    foreach ($vmhost in $vmhosts) {
        write-host "   -- Starting Host : $vmhost"
        $esxcli = get-esxcli -vmhost $vmhost -V2
        $esxcliArgs = $esxcli.software.vib.install.createargs()
        $esxcliArgs.depot = $vibPath
        $esxcliArgs.nosigcheck = $true
        $action = $esxcli.software.vib.install.invoke($esxcliArgs)
        if ($action.Message -eq "Operation finished successfully.") { 
            Write-Host "      VIB installed successfully!" -ForegroundColor Green 
        } else {
            write-host "     ERROR: VIB Installation Failed" -ForegroundColor Red
        }
    }




    Disconnect-VIServer -Confirm:$false

}
#>
