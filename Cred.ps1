function New-SecureCredential {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [string]$EncryptedPasswordFile
    )

    if ([string]::IsNullOrWhiteSpace($Username)) {
        throw 'Credential username is empty.'
    }

    if (-not (Test-Path -LiteralPath $EncryptedPasswordFile -PathType Leaf)) {
        throw "Encrypted credential file not found: '$EncryptedPasswordFile'."
    }

    try {
        # Out-File/Set-Content usually appends a line ending. ConvertTo-SecureString
        # expects only the serialized value, so remove surrounding whitespace first.
        $encryptedPassword = (Get-Content -LiteralPath $EncryptedPasswordFile -Raw -ErrorAction Stop).Trim()

        if ([string]::IsNullOrWhiteSpace($encryptedPassword)) {
            throw 'Credential file is empty.'
        }

        $securePassword = ConvertTo-SecureString -String $encryptedPassword -ErrorAction Stop
        return [System.Management.Automation.PSCredential]::new($Username, $securePassword)
    }
    catch {
        throw "Credential file '$EncryptedPasswordFile' cannot be decrypted by the current Windows account: $($_.Exception.Message)"
    }
}
