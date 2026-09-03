function CreateCredentialObject ($FilePathOrPassword, $Username)
{
    if ($FilePathOrPassword -ne $null)
    {
        # Load password file or use password

        if (Test-Path $FilePathOrPassword) {
            $Password = cat $FilePathOrPassword | ConvertTo-SecureString
        }
        else {
            $Password = ConvertTo-SecureString -String $FilePathOrPassword -AsPlainText -Force
        }

        # Create credential object
        Write-Host ("Creating credential object for " + $Username) -ForegroundColor Green
        $Cred = New-Object -typename System.Management.Automation.PSCredential -ArgumentList $Username, $Password
        Return $Cred
    }
    else
    {
        Write-Host "Password file missing" -ForegroundColor Red
    }
}