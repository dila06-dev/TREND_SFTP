#Requires -Version 5.1

[CmdletBinding()]
param (
    [ValidateSet('HOURLY', 'DAILY', 'ALL')]
    [string]$RunProfile = 'HOURLY',

    # Optional comma-separated customer IDs. When supplied, this selection
    # overrides RunProfile, for example: -Customer PAGERO or -Customer "SCHLANSER,BRACK"
    [string]$Customer,

    [switch]$ListCustomers,

    # Validates configuration, module and encrypted credentials without connecting.
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$packageRoot = $PSScriptRoot
$exitCode = 2
$runLock = $null
$summaries = @()

try {
    $helperScripts = @(
        'Utils.ps1',
        'Cred.ps1',
        'Configuration.ps1',
        'NetworkDrive.ps1',
        'PageroXml.ps1',
        'SftpTransfer.ps1'
    )

    foreach ($helperScript in $helperScripts) {
        $helperPath = Join-Path $packageRoot $helperScript

        if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
            throw "Required script is missing: '$helperPath'."
        }

        . $helperPath
    }

    $configurationPath = Join-Path $packageRoot 'USER_PARAM.ps1'

    if (-not (Test-Path -LiteralPath $configurationPath -PathType Leaf)) {
        throw "Configuration file is missing: '$configurationPath'."
    }

    # USER_PARAM.ps1 returns one object. No global configuration from an older
    # PowerShell run can be reused accidentally.
    $configuration = & $configurationPath
    Assert-TransferConfiguration -Configuration $configuration

    if ($ListCustomers) {
        $configuration.Customers |
            Sort-Object CustomerId |
            Select-Object CustomerId, Enabled, RunProfile, ProcessingMode, Host, RemoteDirectory |
            Format-Table -AutoSize

        exit 0
    }

    $selectedCustomers = @(Get-SelectedCustomers `
        -Configuration $configuration `
        -RunProfile $RunProfile `
        -CustomerFilter $Customer)

    if ($selectedCustomers.Count -eq 0) {
        throw "No enabled customer matched RunProfile '$RunProfile' and Customer '$Customer'."
    }

    Import-Module Posh-SSH -ErrorAction Stop
    Assert-PoshSshCommands

    Set-TransferLogFile -Path $configuration.General.LogFile

    if ($ValidateOnly) {
        # DPAPI-encrypted password files must be readable by the same Windows
        # account that executes the scheduled task.
        New-SecureCredential `
            -Username $configuration.General.NetworkUsername `
            -EncryptedPasswordFile $configuration.General.NetworkCredentialFile | Out-Null

        foreach ($selectedCustomer in $selectedCustomers) {
            New-SecureCredential `
                -Username $selectedCustomer.Username `
                -EncryptedPasswordFile $selectedCustomer.CredentialFile | Out-Null
        }

        Write-Host 'Configuration validation completed successfully.' -ForegroundColor Green
        $selectedCustomers |
            Select-Object CustomerId, RunProfile, ProcessingMode, Host, RemoteDirectory |
            Format-Table -AutoSize

        exit 0
    }

    $runLock = Enter-TransferLock -Path $configuration.General.LockFile
    $exitCode = 0

    Write-TransferLog `
        -Level 'INFO' `
        -Message "Run started. Profile=$RunProfile; Customer=$Customer; Selected=$($selectedCustomers.CustomerId -join ',')"

    foreach ($customerConfig in $selectedCustomers) {
        $sourceDriveMounted = $false
        $sftpSession = $null

        Write-Host "`n[$($customerConfig.CustomerId)] Start transfer" -ForegroundColor Cyan
        Write-TransferLog -Customer $customerConfig.CustomerId -Message 'Customer transfer started.'

        try {
            $sourceRoot = Mount-SourcePath `
                -DriveName $configuration.General.SourceDriveName `
                -SourcePath $customerConfig.SourcePath `
                -NetworkUsername $configuration.General.NetworkUsername `
                -NetworkCredentialFile $configuration.General.NetworkCredentialFile

            $sourceDriveMounted = $true

            $sftpSession = Open-ManagedSftpSession `
                -CustomerConfig $customerConfig `
                -GeneralConfig $configuration.General

            $summary = Invoke-SftpCustomerTransfer `
                -Session $sftpSession `
                -CustomerConfig $customerConfig `
                -SourceRoot $sourceRoot

            $summaries += $summary

            if ($summary.Failed -gt 0) {
                $exitCode = 1
            }
        }
        catch {
            $exitCode = 1
            $message = $_.Exception.Message

            Write-Host "[$($customerConfig.CustomerId)] ERROR: $message" -ForegroundColor Red
            Write-TransferLog -Level 'ERROR' -Customer $customerConfig.CustomerId -Message $message

            $summaries += [PSCustomObject]@{
                CustomerId    = $customerConfig.CustomerId
                Uploaded      = 0
                AlreadyExists = 0
                Skipped       = 0
                Failed        = 1
                Status        = 'FAILED'
            }
        }
        finally {
            if ($null -ne $sftpSession) {
                Close-ManagedSftpSession -Session $sftpSession -CustomerId $customerConfig.CustomerId
                $sftpSession = $null
            }

            if ($sourceDriveMounted) {
                Dismount-SourcePath -DriveName $configuration.General.SourceDriveName
                $sourceDriveMounted = $false
            }
        }
    }

    Write-Host "`nTransfer summary" -ForegroundColor Cyan
    $summaries | Format-Table CustomerId, Uploaded, AlreadyExists, Skipped, Failed, Status -AutoSize

    Write-TransferLog -Message "Run finished. ExitCode=$exitCode"
}
catch {
    $message = $_.Exception.Message
    Write-Host "FATAL ERROR: $message" -ForegroundColor Red

    if (Get-Command Write-TransferLog -ErrorAction SilentlyContinue) {
        Write-TransferLog -Level 'ERROR' -Message "Fatal error: $message"
    }

    $exitCode = 2
}
finally {
    if ($null -ne $runLock) {
        Exit-TransferLock -LockStream $runLock
    }
}

exit $exitCode
