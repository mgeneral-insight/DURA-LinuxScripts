function Write-Log {
        Param ( $text )
        "$(get-date -format "yyyy-MM-dd HH:mm:ss"): $($text)" | out-file "/opt/scripts/vmware/RemoveSnaps.log" -Append
}
[System.Net.Http.HttpClient]::DefaultProxy = New-Object System.Net.WebProxy($null)

$currentdate = Get-Date -UFormat %s
$snapFiles = get-childitem "/opt/scripts/vmware/activesnaps/*"
ForEach ($snapFile in $snapFiles) {
    $snap = Import-Csv $snapFile
    $removeDate = $snap.Remove
    if ($removeDate -lt $currentDate) {
        $takenDate = $snap.Taken
        $vcenter = $snap.vCenter
        $vm = $snap.VM
        $snapname = $snap.SnapName

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
        } else {
            # Delete Snap
            get-vm $vm | get-snapshot -name $snapname | remove-snapshot -confirm:$false
            # Verify for Snap Deleted
            $checksnap = get-vm $vm | Get-Snapshot -Name $snapname
            if ( $null -ne $checksnap ) {
                Write-Log "- ERROR: Snapshot of $vm still exists after attempted delete"
            } else {
                Write-Log "- Snapshot Deleted Successfully!"
                Remove-Item $snapFile
            }
        }
        $disconn = disconnect-viserver * -Confirm:$false
    }
}
