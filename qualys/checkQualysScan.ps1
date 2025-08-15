$username = "durac3na"
$password = "Dinning!ConfettiOxi4"


# Functions
function Write-Log {
        Param ( $text )
        "$(get-date -format "yyyy-MM-dd HH:mm:ss") $($text)" | out-file "/opt/scripts/logs/checkQualysScan.log" -Append
}
function sendEmail {
    $From = "Insight-Automations@duracell.com"
    $SMTPServer = "smtp.duracell.com"
    $SMTPPort = "25"
    $emailArray = $email -split ";"
    if ($email) { Send-MailMessage -From $From -to $emailArray -Subject $emailSubject -Body $emailBody -SmtpServer $SMTPServer -Port $SMTPPort -Attachments $outfile -WarningAction SilentlyContinue }
    Send-MailMessage -From $From -to "michael.general@insight.com", "shaun.fogleman@insight.com" -Subject $emailSubject -Body $emailBody -SmtpServer $SMTPServer -Port $SMTPPort -Attachments $outfile -WarningAction SilentlyContinue
}

$scans = get-childitem "/opt/scripts/linux/qualys/.scanfiles/*"
foreach ($scan in $scans) {
    $activeScan = import-csv $scan
    $server = $activeScan.Server
    [int]$runTime = $activeScan.RunTime
    # Server, HostID, RunTime, LastScan
    [int]$currentTime = get-date -UFormat %s
    $LastScan = $activeScan.LastScan
    $hostID = $activeScan.HostID
    $hostIP = $activeScan.HostIP

    $urlBase = "https://qualysapi.qg3.apps.qualys.com"
    $urlPath = "/qps/rest/2.0/search/am/hostasset/"
    $Url = "$urlBase$urlPath"
    $Headers = @{
        "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$username`:$password"))
        "X-Requested-With" = "Powershell"
        "Content-Type" = "application/json"
        "Accept" = "application/json"
    }
    $body = '{"ServiceRequest": {"filters": {"Criteria": [{"field": "name", "operator": "EQUALS", "value": "' + $server +'"}]}}}'
    $response = Invoke-RestMethod -Headers $Headers -Uri $Url -Method Post -Body $body -ContentType "application/json"

    if ($response.ServiceResponse.count -ne "1") {
        Write-Log "$server-$runtime : ERROR: $server was not found in Qualys"
        break
    } else {
        $newLastScan = [datetime]$response.ServiceResponse.data.HostAsset.vulnsUpdated
        write-log "$server-$runtime : Info: LastScan: $LastScan - newLastScan: $newLastScan"
        if ($LastScan -ne $newLastScan) {
            # Scan Completed, Start Launch Report
            $report_template_id = "5825618"
            $report_title = "Duracell Critical High Medium Severity Report - Exclude NRK"
            $report_format = "csv"
            $urlPath = "/api/2.0/fo/report/"
            $Url = "$urlBase$urlPath"
            $Headers = @{
                "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$username`:$password"))
                "X-Requested-With" = "Powershell"
            }
            $body = @{
                "action" = "launch"
                "template_id" = $report_template_id
                "report_title" = $report_title
                "output_format" = $report_format
                "ips" = $hostIP
                "hide_header" = "1"
            }
            $response = Invoke-RestMethod -Headers $Headers -Uri $Url -Method Post -Body $body
            $reportID = select-xml -content $response.SIMPLE_RETURN.RESPONSE.ITEM_LIST.OuterXml -XPath "/ITEM_LIST/ITEM/VALUE" | ForEach-Object { $_.Node.InnerXML }
            if (!($reportID)) { 
                write-log "$server-$runtime : ERROR: Could not Launch Report"
                break
            } else { 
                # Report Launched, Start Fetch Report
                write-log "$server-$runtime : Info: Report Launched Successfully, Report ID: $reportID"

                $urlPath = "/api/2.0/fo/report/?action=fetch&id=$reportID"
                $Url = "$urlBase$urlPath"
                $Headers = @{
                    "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$username`:$password"))
                    "X-Requested-With" = "Powershell"
                }
                $response = Invoke-RestMethod -Headers $Headers -Uri $Url -Method Post 
                $outfile = "/opt/scripts/reports/Qualys-$server-$currentTime.csv"
                if ($response.SIMPLE_RETURN.RESPONSE.Code) {
                    $i = 0
                    # Report failed to download sleep and try again
                    while ($i -lt 10) {
                        $i++
                        start-sleep -seconds 60 
                        $response = Invoke-RestMethod -Headers $Headers -Uri $Url -Method Post 
                        if (!($response.SIMPLE_RETURN.RESPONSE.Code)) {
                            $i = 11
                        }
                    }
                    if ($response.SIMPLE_RETURN.RESPONSE.Code) {
                        write-log "ERROR: Failed to fetch report" -foregroundcolor red
                        exit 1
                    } else {
                        $response | Out-File -FilePath $outfile -Encoding utf8
                    }
                } else {
                    $response | Out-File -FilePath $outfile -Encoding utf8
                }
                write-log "Report fetched successfully, sending to $email."
                # Email Report
                $emailSubject = "Qualys Report - $server"
                $emailBody = "See attached for vulnerability report"
                sendEmail
                remove-item $scan

            }


        } else {
            # Scan Still Running
            $duration = ($currentTime - $runTime)/60
            write-log "$server-$runTime : Scan still running, duration: $duration minutes"
        }
    }
}
