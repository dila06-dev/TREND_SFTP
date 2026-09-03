#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Utils.ps1')
. (Join-Path $PSScriptRoot 'SftpTransfer.ps1')

$testRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ('TREND_SFTP_AFTERCOPY_' + [guid]::NewGuid().ToString('N'))

try {
    New-Item -ItemType Directory -Path $testRoot -ErrorAction Stop | Out-Null

    $sourcePath = Join-Path $testRoot 'invoice.xml'
    $donePath = Join-Path $testRoot 'invoice.done'
    Set-Content -LiteralPath $sourcePath -Value '<test />' -Encoding UTF8 -ErrorAction Stop

    $testConfig = [PSCustomObject]@{
        CustomerId           = 'LOCAL_TEST'
        AfterCopyAction      = 'RENAME_EXT'
        AfterCopyNewExtension = '.done'
    }

    Invoke-LocalAfterCopyAction `
        -File (Get-Item -LiteralPath $sourcePath -ErrorAction Stop) `
        -CustomerConfig $testConfig

    if (Test-Path -LiteralPath $sourcePath) {
        throw "Source file still exists after .done rename: '$sourcePath'."
    }

    if (-not (Test-Path -LiteralPath $donePath -PathType Leaf)) {
        throw "Expected .done file does not exist: '$donePath'."
    }

    # A pre-existing .done file must never be overwritten silently.
    Set-Content -LiteralPath $sourcePath -Value '<second-test />' -Encoding UTF8 -ErrorAction Stop
    $collisionWasBlocked = $false

    try {
        Invoke-LocalAfterCopyAction `
            -File (Get-Item -LiteralPath $sourcePath -ErrorAction Stop) `
            -CustomerConfig $testConfig
    }
    catch {
        if ($_.Exception.Message -like 'Local post-transfer target already exists:*') {
            $collisionWasBlocked = $true
        }
        else {
            throw
        }
    }

    if (-not $collisionWasBlocked) {
        throw 'A pre-existing .done target was not blocked.'
    }

    Write-Host 'OK: processed source file renamed to .done; collision protection passed.' -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "ERROR: local .done behavior test failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
