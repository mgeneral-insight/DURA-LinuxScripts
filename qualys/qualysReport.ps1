$username = "durac3na"
$password = "Dinning!ConfettiOxi4"
$urlBase = "https://qualysapi.qg3.apps.qualys.com"


$urlPath = "/qps/rest/2.0/search/am/hostasset/"
$Url = "$urlBase$urlPath"

$Headers = @{
    "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$username`:$password"))
    "X-Requested-With" = "Powershell"
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}
if (!($server) { $server = read-host -Prompt "Enter Server Name" }
$server = $server.ToUpper()
$body = '{"ServiceRequest": {"filters": {"Criteria": [{"field": "name", "operator": "EQUALS", "value": "' + $server +'"}]}}}'

write-host "Searching Qualys for $server..."
$response = Invoke-RestMethod -Headers $Headers -Uri $Url -Method Post -Body $body -ContentType "application/json"

if ($response.ServiceResponse.count -ne "1") {
    write-host "ERROR: $server was not found in Qualys" -ForegroundColor Red
} else {
    $hostId = $response.ServiceResponse.data.HostAsset.id
    $hostLastUpdated = [datetime]$response.ServiceResponse.data.HostAsset.vulnsUpdated
    $hostIP = $response.ServiceResponse.data.HostAsset.address
    write-host "Found $server in Qualys."
    write-host "Last vulnerability scan was at $hostLastUpdated"
    Write-Host "You can either run a new scan, which can take up to 3 hours and the report will be emailed to you once it is finished, or you can generate a report with current vulnerability information."
    while ("y","n" -notcontains $runScan) { $runScan = Read-Host -Prompt "Do you want to run a new scan on $server? (y/n)" }
    if ($runScan -eq "y") {
        # Run New Scan
        $urlPath = "/qps/rest/1.0/ods/ca/agentasset/$hostID?scan=Vulnerability_Scan&overrideConfigCpu=false"
        $Url = "$urlBase$urlPath"
        $Headers = @{
            "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$username`:$password"))
            "X-Requested-With" = "Powershell"
            "Content-Type" = "text/xml"
            "Cache-Control" = "no-cache"
        }
        $body = "<?xml version="1.0" encoding="UTF-8"?><ServiceRequest></ServiceRequest>"
        $response = Invoke-RestMethod -Headers $Headers -Uri $Url -Method Post -Body $body -ContentType "text/xml"
    } else {
        # Run Report
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
            #!
        }
        #$reportID = "14100616"
        $urlPath = "/api/2.0/fo/report/?action=fetch&id=$reportID"
        $Url = "$urlBase$urlPath"
        $Headers = @{
            "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$username`:$password"))
            "X-Requested-With" = "Powershell"
        }
        $response = Invoke-RestMethod -Headers $Headers -Uri $Url -Method Post 
        $response | Out-File -FilePath test3.csv -Encoding utf8
    }
}
