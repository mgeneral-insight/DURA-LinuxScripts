[System.Net.Http.HttpClient]::DefaultProxy = New-Object System.Net.WebProxy($null)

function createA {
    $auri = "https://usalp-gminfo-01.duracell.com/wapi/v1.4.1/record:a"
    $adata = @{
        ipv4addr = $ip
        name = $fqdn
    }
    $ajson = $adata | ConvertTo-Json
    Write-Host "Creating A record for $fqdn - $ip" -ForegroundColor Green
    $ares = Invoke-RestMethod -Method Post -Credential $ibcred -SkipCertificateCheck -Uri $auri -Body $ajson -ContentType 'application/json'

}

function createPTR {
    $ptruri = "https://usalp-gminfo-01.duracell.com/wapi/v1.4.1/record:ptr"
    $ptrdata = @{
        ptrdname = $fqdn
        ipv4addr = $ip
    }
    $ptrjson = $ptrdata | ConvertTo-Json
    Write-Host "Creating PTR record for $ip - $fqdn" -ForegroundColor Green
    $ptrres = Invoke-RestMethod -Method Post -Credential $ibcred -SkipCertificateCheck -Uri $ptruri -Body $ptrjson -ContentType 'application/json'

}

function createCNAME {
    $cnameuri = "https://usalp-gminfo-01.duracell.com/wapi/v1.4.1/record:cname"
    $cnamedata = @{
        name = $cfqdn
        canonical = $fqdn
    }
    $cnamejson = $cnamedata | ConvertTo-Json
    Write-Host "Creating CNAME record for $fqdn - $cfqdn" -ForegroundColor Green
    $cnameres = Invoke-RestMethod -Method Post -Credential $ibcred -SkipCertificateCheck -Uri $cnameuri -Body $cnamejson -ContentType 'application/json'

}



$ibp = Get-Content '/opt/scripts/.credfiles/WIN04.cred' | ConvertTo-SecureString
$ibcred = New-Object System.Management.Automation.PSCredential("InsightMSP-Win04",$ibp)

clear-host
get-content -raw /opt/scripts/linux/logo.txt
write-host "This script will create a DNS object in InfoBlox."
write-host ""

while ("y","n" -notcontains $createA) { $createA = Read-Host -Prompt "Do you want to add an A record (y/n)" }
if ($createA -eq "y") {
    while (!($servername)) { $servername = Read-Host -Prompt "Enter hostname for VM (NOT CNAME, No Domain, ie. LGGAWV001)" }
    $fqdn = $servername+".corp.duracell.com"
    while (!($ip)) { $ip = Read-Host -Prompt "Enter IP address for $servername" }
    createA
}
while ("y","n" -notcontains $createPTR) { $createPTR = Read-Host -Prompt "Do you want to add an PTR record (y/n)" }
if ($createPTR -eq "y") {
    while (!($servername)) { $servername = Read-Host -Prompt "Enter hostname for VM (NOT CNAME, No Domain, ie. LGGAWV001)" }
    $fqdn = $servername+".corp.duracell.com"
    while (!($ip)) { $ip = Read-Host -Prompt "Enter IP address for $servername" }
    createPTR
}
while ("y","n" -notcontains $createCNAME) { $createCNAME = Read-Host -Prompt "Do you want to add an CNAME record (y/n)" }
if ($createCNAME -eq "y") {
    while (!($servername)) { $servername = Read-Host -Prompt "Enter hostname for VM (NOT CNAME, No Domain, ie. LGGAWV001)" }
    while (!($cname)) { $cname = Read-Host -Prompt "Enter CNAME for $servername" }
    $cfqdn = $cname+".corp.duracell.com"
    createCNAME
}
