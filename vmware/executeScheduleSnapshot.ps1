[System.Net.Http.HttpClient]::DefaultProxy = New-Object System.Net.WebProxy($null)
$currentTime = Get-Date -UFormat %s
$schedules = get-childitem "/opt/scripts/scheduledSnaps/*"
foreach ($schedule in $schedules) {
    $snap = import-csv $schedule
    $takeTime = $snap.ScheduledTime
    if ($takeTime -le $currentTime) {
        $vc = $snap.vCenter
        $vm = $snap.vm
        $snapName = $snap.SnapName
        $scheduleDate = $snap.ScheduledTime
        $notifyEmail = $snap.NotifyEmail
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
            $body = "Failed to verify successful scheduled snapshot creation of $vm which was scheduled for this time period"
            
            

        } else {
            $snapValid = "Successful"
        }

        #! Notify Email
        $From = "Insight-Automations@duracell.com"
        $Subject = "$vm Snapshot - $snapValid"
        $SMTPServer = "smtp.duracell.com"
        $SMTPPort = "25"
        if ($notifyEmail) { Send-MailMessage -From $From -to $notifyEmail -Subject $Subject -Body $Body -SmtpServer $SMTPServer -Port $SMTPPort }
        Send-MailMessage -From $From -to "michael.general@insight.com" -Subject $Subject -Body $Body -SmtpServer $SMTPServer -Port $SMTPPort


    }
}
