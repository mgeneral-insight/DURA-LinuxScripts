[System.Net.Http.HttpClient]::DefaultProxy = New-Object System.Net.WebProxy($null)
$logo = get-content -raw /opt/scripts/linux/logo.txt
$sourceFile = get-item /opt/.vmtools_vibs/latest/*
#clear-host
Write-Host $logo
Write-Host @"
This script will do the following:
Connect to each vCenter
Get a list of all ESXi hosts
On Each ESXi Host:
- Upload the VMware Tools VIB file to the vSAN Datastore
- Install the VIB file on the ESXi host
- Verify the VIB installed successfully
-------------------------------------------------------------
"@

if ($sourcefile.count -ne 1) { 
    write-host "ERROR: Source VIB File not found or more than one file in Latest Directory /opt/.vmtools_vibs/latest" -foregroundcolor red
#    exit 1
}
$sourceFileName = $sourceFile.name
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
#>
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

