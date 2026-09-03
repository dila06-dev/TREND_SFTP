


# Include Functions
# --------------------------------------------------
$CredScript = Join-Path $PSScriptRoot $CredentionalFile 
. $CredScript

$UtilsScript = Join-Path $PSScriptRoot $UtilsFile
. $UtilsScript


# Create Credential Object
# --------------------------------------------------
$Credentials = CreateCredentialObject -FilePath $SEC_FILE_NETDRIVE -Username $SEC_USER_NETDRIVE

Write-Host "Connect the network drive: $PSDriveName" -ForegroundColor Green
addLog 'START ..............................'
addLog "Connect the network drive: $($PSDriveName)"

#-----------------------------------------------------------------------------------------------------------------------
#Create a temporary drive mapped to a network share
# --------------------------------------------------
addLog "New-PSDrive -Name $($PSDriveName) -PSProvider FileSystem -Root $($NET_DIR)"
Try {
    New-PSDrive -Name $PSDriveName -PSProvider FileSystem -Root $NET_DIR -Credential $Credentials -Scope Global
} Catch {
    addLog "ERROR Connecting => New-PSDrive -Name $($PSDriveName) -PSProvider FileSystem -Root $($NET_DIR)"
    return
}


