
$UtilsScript = Join-Path $PSScriptRoot $UtilsFile
. $UtilsScript

$CredScript = Join-Path $PSScriptRoot $CredentionalFile 
. $CredScript

# Create Credential Object
$Credentials = CreateCredentialObject -FilePath $SFTPPasswordFilePath -Username $SFTPUsername

# Create SFTP Session
Write-Host "Create SFTP session" -ForegroundColor Green
Try{
    $global:SFTPSession = New-SFTPSession -ComputerName $SFTP_Host -Port $SFTP_Port -Credential $Credentials -ConnectionTimeout $Timeout -AcceptKey:$true -ErrorAction Stop -Verbose
}
Catch{
    $mess = $_.Exception.Message
    addLog "ERROR (SFTP): $_"
    Write-Host $mess -ForegroundColor Red
    $SFTPSession = $null
    return
}

