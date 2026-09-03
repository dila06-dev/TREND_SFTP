function Open-ManagedSftpSession {
    param (
        [Parameter(Mandatory = $true)]
        [object]$CustomerConfig,

        [Parameter(Mandatory = $true)]
        [object]$GeneralConfig
    )

    $credential = New-SecureCredential `
        -Username $CustomerConfig.Username `
        -EncryptedPasswordFile $CustomerConfig.CredentialFile

    $sessionParameters = @{
        ComputerName      = $CustomerConfig.Host
        Port              = [int]$CustomerConfig.Port
        Credential        = $credential
        ConnectionTimeout = [int]$GeneralConfig.ConnectionTimeoutSeconds
        OperationTimeout  = [int]$GeneralConfig.OperationTimeoutSeconds
        KeepAliveInterval = [int]$GeneralConfig.KeepAliveSeconds
        ErrorAction       = 'Stop'
    }

    if ($CustomerConfig.AcceptNewHostKey -eq $true) {
        $sessionParameters.AcceptKey = $true
    }
    else {
        $sessionParameters.ErrorOnUntrusted = $true
    }

    Write-Host "Open SFTP session: $($CustomerConfig.Host):$($CustomerConfig.Port)" -ForegroundColor Green
    $session = New-SFTPSession @sessionParameters

    if ($null -eq $session) {
        throw "New-SFTPSession returned no session for '$($CustomerConfig.Host)'."
    }

    return $session
}

function Close-ManagedSftpSession {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Session,

        [Parameter(Mandatory = $true)]
        [string]$CustomerId
    )

    try {
        Remove-SFTPSession -SessionId $Session.SessionId -ErrorAction Stop | Out-Null
        Write-TransferLog -Customer $CustomerId -Message "SFTP session $($Session.SessionId) closed."
    }
    catch {
        $message = "Unable to close SFTP session $($Session.SessionId): $($_.Exception.Message)"
        Write-Warning $message
        Write-TransferLog -Level 'WARN' -Customer $CustomerId -Message $message
    }
}

function Test-SftpRemotePath {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Session,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        return [bool](Test-SFTPPath -SFTPSession $Session -Path $Path -ErrorAction Stop)
    }
    catch {
        if ($_.Exception.Message -match '(?i)(does not exist|not found|no such file)') {
            return $false
        }

        throw
    }
}

function Invoke-LocalAfterCopyAction {
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [object]$CustomerConfig
    )

    $action = ([string]$CustomerConfig.AfterCopyAction).ToUpperInvariant()

    switch ($action) {
        'NONE' {
            return
        }

        'DELETE' {
            Remove-Item -LiteralPath $File.FullName -Force -ErrorAction Stop
            Write-TransferLog `
                -Customer $CustomerConfig.CustomerId `
                -Message "Deleted processed local source file '$($File.Name)'."
            return
        }

        'RENAME_EXT' {
            $newExtension = ([string]$CustomerConfig.AfterCopyNewExtension).Trim()

            if (-not $newExtension.StartsWith('.')) {
                $newExtension = '.' + $newExtension
            }

            $newName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name) + $newExtension
            $newPath = Join-Path $File.DirectoryName $newName

            if (Test-Path -LiteralPath $newPath) {
                throw "Local post-transfer target already exists: '$newPath'."
            }

            Rename-Item -LiteralPath $File.FullName -NewName $newName -ErrorAction Stop
            Write-Host "Marked source file as processed: $($File.Name) -> $newName" -ForegroundColor Green
            Write-TransferLog `
                -Customer $CustomerConfig.CustomerId `
                -Message "Renamed processed local source file '$($File.Name)' to '$newName'."
            return
        }

        default {
            throw "Unsupported AfterCopyAction '$action'."
        }
    }
}

function Invoke-SftpCustomerTransfer {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Session,

        [Parameter(Mandatory = $true)]
        [object]$CustomerConfig,

        [Parameter(Mandatory = $true)]
        [string]$SourceRoot
    )

    if (-not (Test-SftpRemotePath -Session $Session -Path $CustomerConfig.RemoteDirectory)) {
        throw "Remote directory '$($CustomerConfig.RemoteDirectory)' does not exist on '$($CustomerConfig.Host)'."
    }

    $files = @(
        Get-ChildItem -LiteralPath $SourceRoot -File -ErrorAction Stop |
            Where-Object {
                $_.Name -like $CustomerConfig.FilePattern -and
                $_.Extension -ieq $CustomerConfig.FileExtension
            } |
            Sort-Object Name
    )

    $uploaded = 0
    $alreadyExists = 0
    $skipped = 0
    $failed = 0

    foreach ($file in $files) {
        if (-not (Test-LocalFileReady `
            -File $file `
            -MinimumAgeSeconds ([int]$CustomerConfig.MinimumFileAgeSeconds))) {

            $skipped++
            $message = "File skipped because it is too new or locked: '$($file.Name)'."
            Write-Host $message -ForegroundColor Yellow
            Write-TransferLog -Level 'WARN' -Customer $CustomerConfig.CustomerId -Message $message
            continue
        }

        try {
            $processingMode = ([string]$CustomerConfig.ProcessingMode).ToUpperInvariant()

            if ($processingMode -eq 'PAGERO_XML_RENAME') {
                $renamePlan = Get-PageroXmlRenamePlan `
                    -LocalFile $file `
                    -RemoteDirectory $CustomerConfig.RemoteDirectory `
                    -SellerEntityMapping $CustomerConfig.SellerEntityMapping

                if (Test-SftpRemotePath -Session $Session -Path $renamePlan.RemoteTargetPath) {
                    $alreadyExists++
                    $message = "Pagero target already exists; upload skipped: '$($renamePlan.NewFileName)'."
                    Write-Host $message -ForegroundColor Yellow
                    Write-TransferLog -Level 'WARN' -Customer $CustomerConfig.CustomerId -Message $message

                    Invoke-LocalAfterCopyAction -File $file -CustomerConfig $CustomerConfig
                    continue
                }

                Write-Host "Upload Pagero XML: $($file.Name)" -ForegroundColor Green
                Set-SFTPItem `
                    -SFTPSession $Session `
                    -Path $file.FullName `
                    -Destination $CustomerConfig.RemoteDirectory `
                    -Force `
                    -ErrorAction Stop | Out-Null

                Move-SFTPItem `
                    -SFTPSession $Session `
                    -Path $renamePlan.RemoteSourcePath `
                    -Destination $renamePlan.RemoteTargetPath `
                    -ErrorAction Stop | Out-Null

                $uploaded++
                Write-TransferLog `
                    -Customer $CustomerConfig.CustomerId `
                    -Message "Uploaded '$($file.Name)' as '$($renamePlan.NewFileName)'; Seller='$($renamePlan.SellerName)'; Entity='$($renamePlan.Entity)'."
            }
            else {
                # Standard customers keep the exact historical transfer behavior:
                # original filename, configured destination, overwrite enabled.
                Write-Host "Upload standard file: $($file.Name)" -ForegroundColor Green
                Set-SFTPItem `
                    -SFTPSession $Session `
                    -Path $file.FullName `
                    -Destination $CustomerConfig.RemoteDirectory `
                    -Force `
                    -ErrorAction Stop | Out-Null

                $uploaded++
                Write-TransferLog `
                    -Customer $CustomerConfig.CustomerId `
                    -Message "Uploaded standard file '$($file.Name)' to '$($CustomerConfig.RemoteDirectory)'."
            }

            Invoke-LocalAfterCopyAction -File $file -CustomerConfig $CustomerConfig
        }
        catch {
            $failed++
            $message = "File '$($file.Name)' failed: $($_.Exception.Message)"
            Write-Host $message -ForegroundColor Red
            Write-TransferLog -Level 'ERROR' -Customer $CustomerConfig.CustomerId -Message $message
        }
    }

    $status = if ($failed -eq 0) { 'OK' } else { 'FAILED' }

    return [PSCustomObject]@{
        CustomerId    = $CustomerConfig.CustomerId
        Uploaded      = $uploaded
        AlreadyExists = $alreadyExists
        Skipped       = $skipped
        Failed        = $failed
        Status        = $status
    }
}
