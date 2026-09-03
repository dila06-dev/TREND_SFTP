$script:TransferLogFile = $null

function Set-TransferLogFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $logDirectory = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $logDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction Stop | Out-Null
    }

    $script:TransferLogFile = $Path
}

function Write-TransferLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO',

        [string]$Customer
    )

    if ([string]::IsNullOrWhiteSpace($script:TransferLogFile)) {
        return
    }

    $customerText = if ([string]::IsNullOrWhiteSpace($Customer)) { '-' } else { $Customer }
    $line = '{0:yyyy-MM-dd HH:mm:ss.fff} [{1}] [{2}] {3}' -f (Get-Date), $Level, $customerText, $Message

    try {
        Add-Content -LiteralPath $script:TransferLogFile -Value $line -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Warning "Log write failed: $($_.Exception.Message)"
    }
}

function Enter-TransferLock {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $lockDirectory = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $lockDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $lockDirectory -Force -ErrorAction Stop | Out-Null
    }

    try {
        return [System.IO.File]::Open(
            $Path,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
    }
    catch [System.IO.IOException] {
        throw "Another transfer run is already active. Lock file: '$Path'."
    }
}

function Exit-TransferLock {
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.Stream]$LockStream
    )

    $LockStream.Dispose()
}

function Join-SftpPath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Directory,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Directory) -or $Directory -eq '/') {
        return '/' + $Name.TrimStart('/')
    }

    return $Directory.TrimEnd('/') + '/' + $Name.TrimStart('/')
}

function Test-LocalFileReady {
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,

        [int]$MinimumAgeSeconds = 60
    )

    $ageSeconds = ((Get-Date) - $File.LastWriteTime).TotalSeconds

    if ($ageSeconds -lt $MinimumAgeSeconds) {
        return $false
    }

    $stream = $null

    try {
        $stream = [System.IO.File]::Open(
            $File.FullName,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::None
        )

        return $true
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
    }
}
