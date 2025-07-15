function Write-Log {
        Param ( $text )
        "$(get-date -format "yyyy-MM-dd HH:mm:ss") $($text)" | out-file "/opt/scripts/logs/ExecuteScheduledSnaps.log" -Append
}

[System.Net.Http.HttpClient]::DefaultProxy = New-Object System.Net.WebProxy($null)
[int]$currentTime = Get-Date -UFormat %s
$schedules = get-childitem "/opt/scripts/.scheduledSnaps/*"
foreach ($schedule in $schedules) {
    $snap = import-csv $schedule
    [int]$scheduledTime = $snap.ScheduledTime
    $vm = $snap.VM
    $snapName = $snap.SnapName
    if ($scheduledTime -le $currentTime) {
        $vc = $snap.vCenter
        $notifyEmail = $snap.NotifyEmail
        $keepDays = $snap.KeepDays
        [int]$removeTime = $snap.RemoveTime
        if ( $vc -eq 'heivcsa.corp.duracell.com' ) {
            $securePassword = Get-Content '/opt/scripts/.credfiles/hei.cred' | ConvertTo-SecureString
            $credentials = New-Object System.Management.Automation.PSCredential ("administrator@heist.local", $securePassword)
        } else {
            $securePassword = Get-Content '/opt/scripts/.credfiles/vctr.cred' | ConvertTo-SecureString
            $credentials = New-Object System.Management.Automation.PSCredential ("administrator@vsphere.local", $securePassword)
        }
        $conn1 = connect-viserver -server $vc -credential $credentials
        $createsnap = new-snapshot -vm $vm -name $snapName -confirm:$false
        $checksnap = get-vm $vm | get-snapshot -name $snapName
        if ($null -eq $checksnap) {
            $snapValid = "FAILED"
            Write-Log "$vm - $snapName - FAILED to create snapshot"
            $body = "Failed to verify successful scheduled snapshot creation of $vm which was scheduled for this time period"
        } else {
            $snapValid = "Successful"
            $body = "Successfully created snapshot of $vm."
            Write-Log "$vm - $snapName - Snapshot successfully created"
            if ($keepDays) { 
                $body += "`r`nSnapshot will automatically be deleted in $keepDays days." 
                $removeFile = "/opt/scripts/.activeSnaps/$vm-$scheduledTime.csv"
                new-item $removeFile -ItemType File | Out-Null
                Invoke-Command{chmod 666 $removeFile}
                set-content $removeFile 'vCenter, VM, SnapName, Taken, Remove'
                add-content $removeFile "$vc, $vm, $snapName, $currentTime, $removeTime"
            }
        }
        remove-item $schedule
        #! Notify Email
        $From = "Insight-Automations@duracell.com"
        $Subject = "$vm Snapshot - $snapValid"
        $SMTPServer = "smtp.duracell.com"
        $SMTPPort = "25"
        if ($notifyEmail) { Send-MailMessage -From $From -to $notifyEmail -Subject $Subject -Body $Body -SmtpServer $SMTPServer -Port $SMTPPort -WarningAction SilentlyContinue }
        Send-MailMessage -From $From -to "michael.general@insight.com" -Subject $Subject -Body $Body -SmtpServer $SMTPServer -Port $SMTPPort -WarningAction SilentlyContinue
    } else {
        Write-Log "$vm - $snapName - Scheduled Time is in the future, skipping."
    }
}
