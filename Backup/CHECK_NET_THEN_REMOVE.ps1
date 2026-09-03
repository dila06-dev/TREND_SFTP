


# Include Functions
# --------------------------------------------------
$UtilsScript = Join-Path $PSScriptRoot $UtilsFile
. $UtilsScript


#-----------------------------------------------------------------------------------------------------------------------
# Check if multiple connections to the share folder do exist then remove
# --------------------------------------------------
$shareDrives = Get-CimInstance -ClassName Win32_NetworkConnection
if ($shareDrives -ne $null)
{
    foreach ($shareDrive in $shareDrives)
    {
        $name = $shareDrive.Name
        if ($name.StartsWith($NET_DIR)) {
            Write-Host "Removing mapped drive " + $shareDrive.Name
            net use $shareDrive.Name /delete /y
        }
    }
}
else
{
    Write-Host "`nNo mapped drives to remove!" 
}

