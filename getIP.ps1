[System.Net.Http.HttpClient]::DefaultProxy = New-Object System.Net.WebProxy($null)

function getIP {
    Write-Host "Getting next available IP from Infoblox for $location..."
    $ibp = Get-Content '/opt/scripts/.credfiles/WIN04.cred' | ConvertTo-SecureString
    $ibcred = New-Object System.Management.Automation.PSCredential("InsightMSP-Win04",$ibp)
    $uri = "https://usalp-gminfo-01.duracell.com/wapi/v1.4.1/$NetRef`?_function=next_available_ip&num=1"
    $ipresult = Invoke-RestMethod -Uri $uri -Method Post -Credential $ibcred -SkipCertificateCheck
    $ip = $ipresult.ips
    if (!($ip)) { 
        Write-Host "Unable to retrieve next available IP from Infoblox."
    }
    else { 
        Write-Host "Received IP: $ip" 
    }

    return $ip
}

function validateIP {
    $initIP = $ip
    $pingIP = Test-Connection $ip -Count 1 -ErrorAction SilentlyContinue
    $nslookupIP = Resolve-DnsName -QueryType PTR $ip
    $ipRegEx="^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$"
    if ($ip -notmatch $ipRegEx) { Write-Host "ERROR: Invalid IP, Enter IP address for new server" -ForegroundColor Red; $script:ip = Read-Host }
    if ($pingIP.status -ne "TimedOut") { Write-Host "ERROR: IP address $ip responded to ping, enter a free IP address" -ForegroundColor Red; $script:ip = Read-Host }
    else { Write-Host "✓ IP doesn't respond to ping" -ForegroundColor Green }
    if ($nslookupIP.Answers) { Write-Host "ERROR: IP Address resolved to a record in DNS, Please enter a valid FREE IP address" -ForegroundColor Red; $script:ip = Read-Host }
    else { Write-Host "✓ IP doesn't have any DNS entries" -ForegroundColor Green }
    $finIP = $ip
    if ($initIP -ne $finIP) { return "Invalid" }
    else { return "Valid" }
}


function getlocation {
    while ("BECT","LGGA","CVTN","FBGA","CHIL","CNNC","CNDG","HEI","AAR" -notcontains $location ) { 

        Write-Host "Select location to get new IP for:"
        Write-Host "1) BECT - Bethel, CT"
        Write-Host "2) CVTN - Cleveland, TN"
        Write-Host "3) FBGA - Fairburn, GA"
        Write-Host "4) LGGA - LaGrange, GA"
        Write-Host "5) CHIL - Chicago, IL"
        Write-Host "6) AAR - Aarschot, Belgium"
        Write-Host "7) HEI - Heist, Belgium"
        Write-Host "8) CNNC - Nanchang, China"
        Write-Host "9) CNDG - DongGuan, China"
        $loc_sel = Read-Host -Prompt "Select a location (1-9)" 
        switch($loc_sel) {
            '1' { $location = "BECT" }
            '2' { $location = "CVTN" }
            '3' { $location = "FBGA" }
            '4' { $location = "LGGA" }
            '5' { $location = "CHIL" }
            '6' { $location = "AAR" }
            '7' { $location = "HEI" }
            '8' { $location = "CNNC" }
            '9' { $location = "CNDG"}
        }
    }
    return $location
}
clear-host
get-content -raw /opt/scripts/linux/logo.txt
write-host "This script will get the next unused IP for the site you select."
write-host ""

$location = getlocation
if ( $location -eq "CVTN" ) {
    $NetRef = "network/ZG5zLm5ldHdvcmskMTAuMTYuNTAuMC8yMy8w:10.16.50.0/23/default"
}
elseif ( $location -eq "BECT") {
    $NetRef = "network/ZG5zLm5ldHdvcmskMTAuMzIuNTAuMC8yMy8w:10.32.50.0/23/default"
}
elseif ( $location -eq "LGGA" ) {
    $NetRef = "network/ZG5zLm5ldHdvcmskMTAuMjQuNTAuMC8yMy8w:10.24.50.0/23/default"
}
elseif ( $location -eq "FBGA" ) {
    $NetRef = "network/ZG5zLm5ldHdvcmskMTAuNDEuNTAuMC8yMy8w:10.41.50.0/23/default"
}
elseif ( $location -eq "CHIL" ) {
    $NetRef = "network/ZG5zLm5ldHdvcmskMTAuMzkuNTAuMC8yMy8w:10.39.50.0/23/default"
}
elseif ($location -eq "CNNC") { 
    $NetRef = "network/ZG5zLm5ldHdvcmskMTAuNzIuNTAuMC8yMy8w:10.72.50.0/23/default"
}
elseif ($location -eq "CNDG") { 
    $NetRef = "network/ZG5zLm5ldHdvcmskMTAuNzEuNTAuMC8yMy8w:10.71.50.0/23/default"
}
elseif ($location -eq "AAR") {
    $NetRef = "network/ZG5zLm5ldHdvcmskMTAuNTAuNTAuMC8yMy8w:10.50.50.0/23/default"
}
elseif ($location -eq "HEI") { 
    $NetRef = "network/ZG5zLm5ldHdvcmskMTAuNTQuNTAuMC8yMy8w:10.54.50.0/23/default"
}

$ip = getIP
while ($validIP -ne "Valid") { $validIP = validateIP }
