function Write-Log {
        Param ( $text )
        "$(get-date -format "yyyy-MM-dd HH:mm:ss"): $($text)" | out-file "/opt/scripts/vmware/RemoveSnaps.log" -Append
}

[System.Net.Http.HttpClient]::DefaultProxy = New-Object System.Net.WebProxy($null)

$currentdate = Get-Date -UFormat %s
$files = get-childitem "/opt/scripts/vmware/activesnaps/*"
ForEach ($file in $files) {
    $import = Import-Csv $file
    $snapdate = (get-item $file ).basename
    $datediff = $currentdate - $snapdate
    $vcenter = $import.vCenter
    $vm = $import.VM
    $snapname = $import.SnapName
    Write-Log "$snapname - $vm"
    Write-Host "$snapname - $vm"
    if ( $datediff -ge 345600 ) {
        Write-Log "- Snapshot Older than 96 Hours, Deleting..."
        if ( $vcenter -eq 'heivcsa.corp.duracell.com' ) {
            $securePassword = Get-Content '/opt/scripts/vmware/hei.cred' | ConvertTo-SecureString
            $credentials = New-Object System.Management.Automation.PSCredential ("administrator@heist.local", $securePassword)
        } else {
            $securePassword = Get-Content '/opt/scripts/vmware/vctr.cred' | ConvertTo-SecureString
            $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
        }
        $conn = connect-viserver -server $vcenter -credential $credentials
        $getsnap = get-vm $vm | get-snapshot -Name $snapname
        if ( $null -eq $getsnap ) {
            # Snapshot not found on vCenter
            Write-Log "- ERROR: Snapshot of $vm not found on vCenter"
#           Remove-Item $file
        } else {
            # Delete Snap
            get-vm $vm | get-snapshot -name $snapname | remove-snapshot -confirm:$false

            # Verify for Snap Deleted
            $checksnap = get-vm $vm | Get-Snapshot -Name $snapname
            if ( $null -ne $checksnap ) {
                Write-Log "- ERROR: Snapshot of $vm still exists after attempted delete"
            } else {
                Write-Log "- Snapshot Deleted Successfully!"
                Remove-Item $file
            }
        }
        $disconn = disconnect-viserver * -Confirm:$false
    } else {
        Write-Log "- Snapshot not older than 96 hours, ignoring"
    }
}
