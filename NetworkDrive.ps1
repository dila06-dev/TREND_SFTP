function Mount-SourcePath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DriveName,

        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$NetworkUsername,

        [Parameter(Mandatory = $true)]
        [string]$NetworkCredentialFile,

        [Parameter(Mandatory = $true)]
        [string]$CustomerId,

        [int]$RetryCount = 3,

        [int]$RetryDelaySeconds = 5
    )

    if ($null -ne (Get-PSDrive -Name $DriveName -ErrorAction SilentlyContinue)) {
        throw "PowerShell drive '$DriveName' already exists. A previous run may not have terminated cleanly."
    }

    $credential = New-SecureCredential `
        -Username $NetworkUsername `
        -EncryptedPasswordFile $NetworkCredentialFile

    $driveRoot = $DriveName + ':\'
    $lastErrorMessage = $null

    if ($RetryCount -lt 1) {
        throw 'RetryCount must be at least 1.'
    }

    if ($RetryDelaySeconds -lt 0) {
        throw 'RetryDelaySeconds cannot be negative.'
    }

    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            Write-Host "Mount source path (attempt $attempt/$RetryCount): $SourcePath" -ForegroundColor Green

            New-PSDrive `
                -Name $DriveName `
                -PSProvider FileSystem `
                -Root $SourcePath `
                -Credential $credential `
                -Scope Global `
                -ErrorAction Stop | Out-Null

            if (-not (Test-Path -LiteralPath $driveRoot -PathType Container -ErrorAction Stop)) {
                throw "Mounted source path is not accessible: '$SourcePath'."
            }

            Write-TransferLog `
                -Customer $CustomerId `
                -Message "SMB source connected on attempt {$attempt/$RetryCount}: '$SourcePath'."

            return $driveRoot
        }
        catch {
            $lastErrorMessage = $_.Exception.Message
            Remove-PSDrive -Name $DriveName -Force -ErrorAction SilentlyContinue

            if ($attempt -lt $RetryCount) {
                $message = "SMB source connection attempt $attempt/$RetryCount failed: $lastErrorMessage Retrying in $RetryDelaySeconds second(s)."
                Write-Warning $message
                Write-TransferLog -Level 'WARN' -Customer $CustomerId -Message $message

                if ($RetryDelaySeconds -gt 0) {
                    Start-Sleep -Seconds $RetryDelaySeconds
                }
            }
        }
    }

    throw "SMB source path '$SourcePath' could not be mounted after $RetryCount attempt(s): $lastErrorMessage"
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
