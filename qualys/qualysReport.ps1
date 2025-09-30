$username = "durac3na"
$password = "Dinning!ConfettiOxi4"
$urlBase = "https://qualysapi.qg3.apps.qualys.com"
$currentTime = get-date -UFormat %s

# Functions
function sendEmail {
    $From = "Insight-Automations@duracell.com"
    $SMTPServer = "smtp.duracell.com"
    $SMTPPort = "25"
    $emailArray = $email -split ";"
    if ($email) { Send-MailMessage -From $From -to $emailArray -Subject $emailSubject -Body $emailBody -SmtpServer $SMTPServer -Port $SMTPPort -Attachments $outfile -WarningAction SilentlyContinue }
    Send-MailMessage -From $From -to "michael.general@insight.com", "shaun.fogleman@insight.com" -Subject $emailSubject -Body $emailBody -SmtpServer $SMTPServer -Port $SMTPPort -Attachments $outfile -WarningAction SilentlyContinue
}

# Run Script

clear-host
get-content -raw /opt/scripts/linux/logo.txt
write-host @"
This script will do the following:
-Search Qualys for the server you input
-Get the date of last vulnerability scan
-Prompt to run new scan or use current data
-If a new scan is run, scan process will be monitored in the background and once complete report will be emailed to you.
-If current data is used a report will be generated and emailed to you immediately
"@
write-host ""

$urlPath = "/qps/rest/2.0/search/am/hostasset/"
$Url = "$urlBase$urlPath"
$Headers = @{
    "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$username`:$password"))
    "X-Requested-With" = "Powershell"
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}
if (!($server)) { $server = read-host -Prompt "Enter Server Name" }
$server = $server.ToLower()
#$body = '{"ServiceRequest": {"filters": {"Criteria": [{"field": "name", "operator": "EQUALS", "value": "' + $server +'"}]}}}'
$body = '{"ServiceRequest": {"filters": {"Criteria": [{"field": "dnsHostName", "operator": "EQUALS", "value": "' + $server +'.corp.duracell.com"}]}}}'

$body
write-host "Searching Qualys for $server..."
# Search for Server
$response = Invoke-RestMethod -Headers $Headers -Uri $Url -Method Post -Body $body -ContentType "application/json"

if ($response.ServiceResponse.count -ne "1") {
    write-host "ERROR: $server was not found in Qualys" -ForegroundColor Red
} else {
    $hostId = $response.ServiceResponse.data.HostAsset.id
    $hostLastUpdated = [datetime]$response.ServiceResponse.data.HostAsset.vulnsUpdated
    $hostIP = $response.ServiceResponse.data.HostAsset.address
    write-host "Found $server in Qualys.`r`n"
    write-host "Last vulnerability scan was at $hostLastUpdated EST`r`n" 
    Write-Host "You can either run a new scan, which can take up to 3 hours and the report will be emailed to you once it is finished"
    Write-Host "or you can generate a report with current vulnerability information."
    while ("y","n" -notcontains $runScan) { $runScan = Read-Host -Prompt "Do you want to run a new scan on $server (y/n)" }
    $email = read-host -Prompt "Enter email address to send report to (separate multiple with semicolon ;)"
    while ($email.contains(",")) { $email = read-host -prompt "Enter email address to send report to (separate multiple with semicolon ;) DO NOT USE COMMAs ," }

    if ($runScan -eq "y") {
        write-host "Initiating Vulnerability Scan on $server"
        # Run New Scan
        $urlPath = "/qps/rest/1.0/ods/ca/agentasset/" + $hostID + "?scan=Vulnerability_Scan&overrideConfigCpu=false"
        $Url = "$urlBase$urlPath"
        $Headers = @{
            "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$username`:$password"))
            "X-Requested-With" = "Powershell"
            "Content-Type" = "text/xml"
            "Cache-Control" = "no-cache"
        }
        $body = '<?xml version="1.0" encoding="UTF-8"?><ServiceRequest></ServiceRequest>'
        # Run Scan
        $response = Invoke-RestMethod -Headers $Headers -Uri $Url -Method Post -Body $body -ContentType "text/xml"
        if ($response.ServiceResponse.responseCode -eq "SUCCESS") {
            Write-Host "New Scan Successfully Started, report will be emailed once complete (this can take up to 3 hours)."
            $scanFile = "/opt/scripts/linux/qualys/.scanfiles/$server-$currentTime.csv"
            set-content $scanFile 'Server, HostID, HostIP, RunTime, LastScan, Email'
            add-content $scanFile "$server, $hostID, $hostIP, $currentTime, $hostLastUpdated, $email"
        } else {
            Write-Host "ERROR: Failed to start a new scan"
            exit 1
        }
    } else {
        # Run Report
        write-host "Generating Vulnerability Report for $server (this can take a few minutes)."
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
            write-host "ERROR: Failed to launch the report."
        } else {
            # Report Launched - Start Fetch Report
            write-host "Report Generated Successfully, Fetching report and emailing."
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
                    write-host "ERROR: Failed to fetch report" -foregroundcolor red
                    exit 1
                } else {
                    $response | Out-File -FilePath $outfile -Encoding utf8
                }
            } else {
                $response | Out-File -FilePath $outfile -Encoding utf8
            }
            write-host "Report fetched successfully, sending to $email."
            # Email Report
            $emailSubject = "Qualys Report - $server"
            $emailBody = "See attached for vulnerability report"
            sendEmail
        }
    }
}
