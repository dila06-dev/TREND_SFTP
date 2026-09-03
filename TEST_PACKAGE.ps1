#Requires -Version 5.1

$ErrorActionPreference = 'Stop'
$parseFailureCount = 0

Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File |
    Sort-Object Name |
    ForEach-Object {
        $tokens = $null
        $parseErrors = $null

        [void][System.Management.Automation.Language.Parser]::ParseFile(
            $_.FullName,
            [ref]$tokens,
            [ref]$parseErrors
        )

        if (@($parseErrors).Count -eq 0) {
            Write-Host "OK: $($_.Name)" -ForegroundColor Green
        }
        else {
            foreach ($parseError in $parseErrors) {
                $parseFailureCount++
                Write-Host `
                    "ERROR: $($_.Name):$($parseError.Extent.StartLineNumber): $($parseError.Message)" `
                    -ForegroundColor Red
            }
        }
    }

if ($parseFailureCount -gt 0) {
    Write-Host "Package syntax validation failed with $parseFailureCount error(s)." -ForegroundColor Red
    exit 1
}

try {
    . (Join-Path $PSScriptRoot 'Configuration.ps1')

    $configuration = & (Join-Path $PSScriptRoot 'USER_PARAM.ps1')
    Assert-TransferConfiguration -Configuration $configuration
    Write-Host 'OK: configuration and .done business rule' -ForegroundColor Green

    & (Join-Path $PSScriptRoot 'TEST_AFTER_COPY.ps1')

    if ($LASTEXITCODE -ne 0) {
        throw "TEST_AFTER_COPY.ps1 returned exit code $LASTEXITCODE."
    }
}
catch {
    Write-Host "ERROR: package behavior validation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host 'All PowerShell files and local behavior tests passed.' -ForegroundColor Green
exit 0
