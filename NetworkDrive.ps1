function Mount-SourcePath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DriveName,

        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$NetworkUsername,

        [Parameter(Mandatory = $true)]
        [string]$NetworkCredentialFile
    )

    if ($null -ne (Get-PSDrive -Name $DriveName -ErrorAction SilentlyContinue)) {
        throw "PowerShell drive '$DriveName' already exists. A previous run may not have terminated cleanly."
    }

    $credential = New-SecureCredential `
        -Username $NetworkUsername `
        -EncryptedPasswordFile $NetworkCredentialFile

    Write-Host "Mount source path: $SourcePath" -ForegroundColor Green

    New-PSDrive `
        -Name $DriveName `
        -PSProvider FileSystem `
        -Root $SourcePath `
        -Credential $credential `
        -Scope Global `
        -ErrorAction Stop | Out-Null

    $driveRoot = $DriveName + ':\'

    if (-not (Test-Path -LiteralPath $driveRoot -PathType Container)) {
        Remove-PSDrive -Name $DriveName -Force -ErrorAction SilentlyContinue
        throw "Mounted source path is not accessible: '$SourcePath'."
    }

    return $driveRoot
}

function Dismount-SourcePath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DriveName
    )

    try {
        $drive = Get-PSDrive -Name $DriveName -ErrorAction SilentlyContinue

        if ($null -ne $drive) {
            Remove-PSDrive -Name $DriveName -Force -ErrorAction Stop
        }
    }
    catch {
        $message = "Unable to remove PowerShell drive '$DriveName': $($_.Exception.Message)"
        Write-Warning $message
        Write-TransferLog -Level 'WARN' -Message $message
    }
}
