# Unified configuration for every SFTP customer.
#
# RunProfile controls the Task Scheduler group:
#   HOURLY = called by the hourly task
#   DAILY  = called by the daily task
#
# ProcessingMode controls customer-specific processing:
#   STANDARD          = unchanged upload using the original file name
#   PAGERO_XML_RENAME = XML seller mapping and remote rename for Pagero only

$baseDirectory = 'D:\TREND_SFTP'
$secureDirectory = Join-Path $baseDirectory 'secure'

[PSCustomObject]@{
    General = [PSCustomObject]@{
        LogFile                  = Join-Path $baseDirectory 'Log\transfer.log'
        LockFile                 = Join-Path $baseDirectory 'Log\transfer.lock'
        SourceDriveName          = 'TREND_SRC'
        NetworkUsername          = 'Bari'
        NetworkCredentialFile    = Join-Path $secureDirectory 'trend.sec'
        ConnectionTimeoutSeconds = 30
        OperationTimeoutSeconds  = 120
        KeepAliveSeconds         = 15
    }

    Customers = @(
        # Standard CSV transfer: unchanged behavior and unchanged remote name.
        [PSCustomObject]@{
            CustomerId           = 'SCHLANSER'
            Enabled              = $true
            RunProfile           = 'DAILY'
            ProcessingMode       = 'STANDARD'
            Host                 = 'www143.your-server.de'
            Port                 = 22
            Username             = 'schlanb_0'
            CredentialFile       = Join-Path $secureDirectory 'schlanser.sec'
            SourcePath           = '\\S105DD7A.dometic.internal\SCHLANSER'
            RemoteDirectory      = '/'
            FilePattern          = 'SCHLANSERout_*.csv'
            FileExtension        = '.csv'
            MinimumFileAgeSeconds = 60
            AcceptNewHostKey     = $true
            # A successfully processed source file is marked locally as .done.
            AfterCopyAction      = 'RENAME_EXT'
            AfterCopyNewExtension = '.done'
            SellerEntityMapping  = $null
        }

        # Standard CSV transfer: unchanged behavior and unchanged remote name.
        [PSCustomObject]@{
            CustomerId           = 'GALAXUS'
            Enabled              = $true
            RunProfile           = 'DAILY'
            ProcessingMode       = 'STANDARD'
            Host                 = 'ftp.digitecgalaxus.ch'
            Port                 = 22
            Username             = 'igloo'
            CredentialFile       = Join-Path $secureDirectory 'digitecgalaxus.sec'
            SourcePath           = '\\S105DD7A.dometic.internal\GALAXUSI'
            RemoteDirectory      = '/StockData_EU'
            FilePattern          = 'GALAXI_OUT_*.csv'
            FileExtension        = '.csv'
            MinimumFileAgeSeconds = 60
            AcceptNewHostKey     = $true
            # A successfully processed source file is marked locally as .done.
            AfterCopyAction      = 'RENAME_EXT'
            AfterCopyNewExtension = '.done'
            SellerEntityMapping  = $null
        }

        # Standard CSV transfer: unchanged behavior and unchanged remote name.
        [PSCustomObject]@{
            CustomerId           = 'BRACK'
            Enabled              = $true
            RunProfile           = 'DAILY'
            ProcessingMode       = 'STANDARD'
            Host                 = 'files.competec.ch'
            Port                 = 22
            Username             = 'A5363'
            CredentialFile       = Join-Path $secureDirectory 'brack.sec'
            SourcePath           = '\\S105DD7A.dometic.internal\BRACK'
            RemoteDirectory      = '/pricelistimport'
            FilePattern          = 'BRACKout_*.csv'
            FileExtension        = '.csv'
            MinimumFileAgeSeconds = 60
            AcceptNewHostKey     = $true
            # A successfully processed source file is marked locally as .done.
            AfterCopyAction      = 'RENAME_EXT'
            AfterCopyNewExtension = '.done'
            SellerEntityMapping  = $null
        }

        # Pagero is the only customer for which XML content is evaluated and
        # the uploaded remote file is renamed.
        [PSCustomObject]@{
            CustomerId           = 'PAGERO'
            Enabled              = $true
            RunProfile           = 'HOURLY'
            ProcessingMode       = 'PAGERO_XML_RENAME'
            Host                 = 'dometicsftpqa.blob.core.windows.net'
            Port                 = 22
            Username             = 'dometicsftpqa.pagero.trendusr'
            CredentialFile       = Join-Path $secureDirectory 'pagero2.sec'
            SourcePath           = '\\S105DD7A.dometic.internal\TREND\echt\e-Rechnungen'
            RemoteDirectory      = '/in'
            FilePattern          = '*.xml'
            FileExtension        = '.xml'
            MinimumFileAgeSeconds = 60
            AcceptNewHostKey     = $true

            # After a successful upload/remote rename, or when the deterministic
            # Pagero target already exists, mark the local source file as .done.
            AfterCopyAction      = 'RENAME_EXT'
            AfterCopyNewExtension = '.done'

            SellerEntityMapping  = @{
                'Dometic Benelux B.V.' = 'DE13'
            }
        }
    )
}
