


# Include Functions
# --------------------------------------------------

$UtilsScript = Join-Path $PSScriptRoot $UtilsFile
. $UtilsScript

#-----------------------------------------------------------------------------------------------------------------------
Write-Host "Disconnect the network drive: $PSDriveName" -ForegroundColor Green
# Disconnect drive
# --------------------------------------------------
addLog "Disconnect the network drive: $($PSDriveName)"

Try{
    Remove-PSDrive -Name $PSDriveName 
    #Get-PSdrive -Name $PSDriveName | Remove-PSDrive
    #Get-PSdrive -Name $PSDriveName | Remove-PSDrive -ErrorAction SilentlyContinue -ErrorVariable rmDrive
}
Catch{
    $mess = $_.Exception.Message
    addLog $mess
    Write-Host $mess -ForegroundColor Red
    return
}

addLog 'END ................................'

# End of Script
# --------------------------------------------------

