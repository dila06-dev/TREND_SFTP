
Param(
   [string]$collectionUrl = "https://esolutions.dpd.com/partnerloesungen/hazdistributionservice.aspx",
   [string]$project = "DPD Routing data",
   [string]$releaseid = "35",
   [string]$filename = "D:\temp\ReleaseLogs_$releaseid.zip",
   [string]$user = "username",
   [string]$token = "password/PAT"
)

# Base64-encodes the Personal Access Token (PAT) appropriately
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user,$token)))

$uri = "$collectionUrl/$project/_apis/Release/releases/$releaseid/logs"

Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/zip" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -OutFile $filename


Invoke-RestMethod https://esolutions.dpd.com/partnerloesungen/hazdistributionservice.aspx