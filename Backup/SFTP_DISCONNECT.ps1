
$UtilsScript = Join-Path $PSScriptRoot $UtilsFile
. $UtilsScript

if($Session -ne $null){
    Write-Host "Disconnect SFTP session" -ForegroundColor Green
    Remove-SFTPSession $SFTPSession | Out-Null
}





