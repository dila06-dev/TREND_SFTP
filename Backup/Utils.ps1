

function Get-FormatedTimestamp 
{
    Return (Get-Date -Format o | ForEach-Object { $_ -replace ":", "." } | ForEach-Object { $_ -replace "T", "-" } | ForEach-Object { $_ -replace "\+", "." })
}


function addLog {
    Param (
    [string]$LogString = '', 
    [string]$LogFile = $Log
    )

    $ts = Get-FormatedTimestamp
    $LogMessage = ('[' + $ts + ']: ' + $LogString)

    Add-content -Path $LogFile -value $LogMessage
}

Function rdbl {
    param (
        [string]$timestamp = ((Get-Date) - (New-TimeSpan -Days 1)).ToString("yyyy-MM-dd")
    )
    Write-Host $timestamp
}


