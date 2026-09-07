#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
$testDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('trend-sftp-source-test-' + [guid]::NewGuid().ToString('N'))

try {
    . (Join-Path $PSScriptRoot 'SftpTransfer.ps1')

    New-Item -ItemType Directory -Path $testDirectory -ErrorAction Stop | Out-Null

    $customerConfig = [PSCustomObject]@{
        FilePattern   = '*.xml'
        FileExtension = '.xml'
    }

    New-Item -ItemType File -Path (Join-Path $testDirectory '2026600172.done') -ErrorAction Stop | Out-Null
    New-Item -ItemType File -Path (Join-Path $testDirectory 'ignore.csv') -ErrorAction Stop | Out-Null

    $files = @(Get-SourceTransferFiles -CustomerConfig $customerConfig -SourceRoot $testDirectory)

    if ($files.Count -ne 0) {
        throw "Expected no active XML files, but found $($files.Count)."
    }

    New-Item -ItemType File -Path (Join-Path $testDirectory '2026600173.xml') -ErrorAction Stop | Out-Null
    $files = @(Get-SourceTransferFiles -CustomerConfig $customerConfig -SourceRoot $testDirectory)

    if ($files.Count -ne 1 -or $files[0].Name -ne '2026600173.xml') {
        throw 'Active XML source selection returned an unexpected result.'
    }

    Write-Host 'OK: no active source file is a normal empty selection; .done files are ignored.' -ForegroundColor Green
}
catch {
    throw "Source selection test failed: $($_.Exception.Message)"
}
finally {
    if (Test-Path -LiteralPath $testDirectory) {
        Remove-Item -LiteralPath $testDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}
