function Assert-ObjectProperties {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Object,

        [Parameter(Mandatory = $true)]
        [string[]]$Properties,

        [Parameter(Mandatory = $true)]
        [string]$ObjectName
    )

    foreach ($propertyName in $Properties) {
        if ($Object.PSObject.Properties.Name -notcontains $propertyName) {
            throw "$ObjectName is missing property '$propertyName'."
        }
    }
}

function Assert-TransferConfiguration {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Configuration
    )

    Assert-ObjectProperties `
        -Object $Configuration `
        -ObjectName 'Configuration' `
        -Properties @('General', 'Customers')

    Assert-ObjectProperties `
        -Object $Configuration.General `
        -ObjectName 'General configuration' `
        -Properties @(
            'LogFile',
            'LockFile',
            'SourceDriveName',
            'NetworkUsername',
            'NetworkCredentialFile',
            'ConnectionTimeoutSeconds',
            'OperationTimeoutSeconds',
            'KeepAliveSeconds'
        )

    $requiredCustomerProperties = @(
        'CustomerId',
        'Enabled',
        'RunProfile',
        'ProcessingMode',
        'Host',
        'Port',
        'Username',
        'CredentialFile',
        'SourcePath',
        'RemoteDirectory',
        'FilePattern',
        'FileExtension',
        'MinimumFileAgeSeconds',
        'AcceptNewHostKey',
        'AfterCopyAction',
        'AfterCopyNewExtension',
        'SellerEntityMapping'
    )

    $knownIds = @{}

    foreach ($customer in @($Configuration.Customers)) {
        $customerLabel = 'Customer configuration'

        if ($customer.PSObject.Properties.Name -contains 'CustomerId') {
            $customerLabel = "Customer '$($customer.CustomerId)'"
        }

        Assert-ObjectProperties `
            -Object $customer `
            -ObjectName $customerLabel `
            -Properties $requiredCustomerProperties

        $customerId = ([string]$customer.CustomerId).Trim().ToUpperInvariant()

        if ([string]::IsNullOrWhiteSpace($customerId)) {
            throw 'A customer has an empty CustomerId.'
        }

        if ($knownIds.ContainsKey($customerId)) {
            throw "Duplicate CustomerId '$customerId'."
        }

        $knownIds[$customerId] = $true

        if (([string]$customer.RunProfile).ToUpperInvariant() -notin @('HOURLY', 'DAILY')) {
            throw "Customer '$customerId' has invalid RunProfile '$($customer.RunProfile)'."
        }

        $mode = ([string]$customer.ProcessingMode).ToUpperInvariant()

        if ($mode -notin @('STANDARD', 'PAGERO_XML_RENAME')) {
            throw "Customer '$customerId' has invalid ProcessingMode '$($customer.ProcessingMode)'."
        }

        if ($mode -eq 'PAGERO_XML_RENAME') {
            if ($customerId -ne 'PAGERO') {
                throw "PAGERO_XML_RENAME is restricted to CustomerId 'PAGERO', not '$customerId'."
            }

            if ($customer.FileExtension -ine '.xml') {
                throw "Customer '$customerId' uses PAGERO_XML_RENAME but FileExtension is not '.xml'."
            }

            if ($null -eq $customer.SellerEntityMapping -or $customer.SellerEntityMapping.Count -eq 0) {
                throw "Customer '$customerId' uses PAGERO_XML_RENAME without SellerEntityMapping."
            }
        }

        if ($customerId -eq 'PAGERO' -and $mode -ne 'PAGERO_XML_RENAME') {
            throw "Customer 'PAGERO' must use ProcessingMode 'PAGERO_XML_RENAME'."
        }

        if ([string]::IsNullOrWhiteSpace($customer.RemoteDirectory) -or -not $customer.RemoteDirectory.StartsWith('/')) {
            throw "Customer '$customerId' must use an absolute SFTP RemoteDirectory beginning with '/'."
        }

        if ([string]::IsNullOrWhiteSpace($customer.FileExtension) -or -not $customer.FileExtension.StartsWith('.')) {
            throw "Customer '$customerId' has invalid FileExtension '$($customer.FileExtension)'."
        }

        $afterAction = ([string]$customer.AfterCopyAction).ToUpperInvariant()

        if ($afterAction -notin @('NONE', 'DELETE', 'RENAME_EXT')) {
            throw "Customer '$customerId' has invalid AfterCopyAction '$($customer.AfterCopyAction)'."
        }

        if ($afterAction -eq 'RENAME_EXT' -and [string]::IsNullOrWhiteSpace($customer.AfterCopyNewExtension)) {
            throw "Customer '$customerId' uses RENAME_EXT without AfterCopyNewExtension."
        }

        # Business rule: every successfully processed source file must leave
        # the active input pattern and be marked with the .done extension.
        if ($customer.Enabled -eq $true) {
            $afterExtension = ([string]$customer.AfterCopyNewExtension).Trim()

            if (-not $afterExtension.StartsWith('.')) {
                $afterExtension = '.' + $afterExtension
            }

            if ($afterAction -ne 'RENAME_EXT' -or $afterExtension -ine '.done') {
                throw "Enabled customer '$customerId' must use AfterCopyAction 'RENAME_EXT' with AfterCopyNewExtension '.done'."
            }
        }
    }
}

function Get-SelectedCustomers {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Configuration,

        [Parameter(Mandatory = $true)]
        [string]$RunProfile,

        [string]$CustomerFilter
    )

    $enabledCustomers = @($Configuration.Customers | Where-Object { $_.Enabled -eq $true })

    if (-not [string]::IsNullOrWhiteSpace($CustomerFilter)) {
        $requestedIds = @(
            $CustomerFilter.Split(',') |
                ForEach-Object { $_.Trim().ToUpperInvariant() } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique
        )

        $knownIds = @($Configuration.Customers | ForEach-Object { $_.CustomerId.ToUpperInvariant() })
        $unknownIds = @($requestedIds | Where-Object { $knownIds -notcontains $_ })

        if ($unknownIds.Count -gt 0) {
            throw "Unknown CustomerId: $($unknownIds -join ', ')."
        }

        $disabledIds = @(
            $Configuration.Customers |
                Where-Object { $_.Enabled -ne $true -and $requestedIds -contains $_.CustomerId.ToUpperInvariant() } |
                ForEach-Object { $_.CustomerId }
        )

        if ($disabledIds.Count -gt 0) {
            throw "Requested customer is disabled: $($disabledIds -join ', ')."
        }

        return $enabledCustomers | Where-Object { $requestedIds -contains $_.CustomerId.ToUpperInvariant() }
    }

    if ($RunProfile -eq 'ALL') {
        return $enabledCustomers
    }

    return $enabledCustomers | Where-Object { $_.RunProfile -ieq $RunProfile }
}

function Assert-PoshSshCommands {
    $requiredCommands = @(
        'New-SFTPSession',
        'Remove-SFTPSession',
        'Set-SFTPItem',
        'Move-SFTPItem',
        'Test-SFTPPath'
    )

    foreach ($commandName in $requiredCommands) {
        if ($null -eq (Get-Command $commandName -ErrorAction SilentlyContinue)) {
            throw "Required Posh-SSH command '$commandName' is not available."
        }
    }
}
