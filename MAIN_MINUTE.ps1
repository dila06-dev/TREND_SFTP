

# Utils
# --------------------------------------------------
$global:UtilsFile            = "Utils.ps1"

# Credentional Object
# --------------------------------------------------
$global:CredentionalFile     = "Cred.ps1"

# Name of temporary Network Drive
# --------------------------------------------------
$global:PSDriveName = 'M'

# Archive
# --------------------------------------------------
$global:Loc_archive = 'D:\TREND_SFTP\Archive'

#Logfiles
# --------------------------------------------------
$global:Log = 'D:\TREND_SFTP\Log\log.txt'

# Credential to access Network Drive
# --------------------------------------------------
$global:SEC_FILE_NETDRIVE='D:\TREND_SFTP\secure\trend.sec'


# Credential to access Network Drive
# --------------------------------------------------
$global:SFTPSession          = $null
$global:SEC_USER_NETDRIVE    = 'Bari'
$global:Timeout              = 30
# --------------------------------------------------
$global:default_ftp_port     = '22'
$global:default_file_ext     = '.csv'
$global:default_ftp_dir     = '/'


cd 'D:\TREND_SFTP'

..\SFTP\USER_PARAM2.ps1


$global:user_parameter | ForEach-Object {

    if(!$_.PORT) {
        $_.PORT = $default_ftp_port
    }

    if(!$_.FTP_DIR) {
        $_.FTP_DIR = $default_ftp_dir
    }

    # FILE_EXT is optional in older parameter files.
    # Do not add the property to the PSCustomObject; use a local fallback value.
    $fileExtForCurrentConnection = if ($_.FILE_EXT) { $_.FILE_EXT } else { $default_file_ext }

    if(!$_.FILE_LIKE) {
        $_.FILE_LIKE = '*' + $fileExtForCurrentConnection
    }

    if($_.FTP_HOST -and $_.LOC_DIR -and $_.PW_FILE -and $_.PW_USER) {

        $global:SFTP_Host            = $_.FTP_HOST
        $global:SFTP_Port            = $_.PORT
        $global:NET_DIR              = $_.LOC_DIR
        $global:SFTPPasswordFilePath = $_.PW_FILE
        $global:SFTPUsername         = $_.PW_USER
        $global:FILE_CLIKE           = $_.FILE_LIKE
        $global:FILE_PATH_TARGET     = $_.FTP_DIR
        $global:FILE_PATH_SOURCE     = $NET_DIR
        $global:FILE_EXT             = $fileExtForCurrentConnection


        .\CHECK_NET_THEN_REMOVE.ps1
        .\MAP_NET_DRIVE.ps1
        .\FIND_HOSTS_BYNAME.ps1 -Path $NET_DIR
        .\SFTP_CONNECT.ps1
        # Load XML seller-to-entity mapping and SFTP rename functions.
        . .\SFTP_RENAME_XML.ps1
        .\SFTP_COPY.ps1
        .\SFTP_DISCONNECT.ps1
        .\REMOVE_NET_DRIVE.ps1

    }
}





