$UtilsScript = Join-Path $PSScriptRoot $UtilsFile
. $UtilsScript


# Copy files to SFTP server

Write-Host 'Check sftp session'

if ($SFTPSession -eq $null) {
    Write-Warning 'SFTP server is not connected'
    return
}

# Mögliche Werte:
# NONE       = Datei bleibt unverändert
# DELETE     = Datei nach erfolgreichem Kopieren löschen
# RENAME_EXT = Dateiendung nach erfolgreichem Kopieren ändern
#
# Beispiel:
# $AFTER_COPY_ACTION = "RENAME_EXT"
# $AFTER_COPY_NEW_EXT = ".done"

if ([string]::IsNullOrWhiteSpace($AFTER_COPY_ACTION)) {
    $AFTER_COPY_ACTION = "NONE"
}

try {

    $files = Get-ChildItem $FILE_PATH_SOURCE -File

    # Upload the file to the SFTP path
    foreach ($srcFile in $files) {

        $f = $srcFile.FullName

        $extn = [IO.Path]::GetExtension($srcFile.Name)

        if ($extn -ieq $FILE_EXT -and $srcFile.Name -like $FILE_CLIKE) {

            Write-Host "Start transferring the file to SFTP server, -Path $f -Destination $FILE_PATH_TARGET"
            addLog "Start transferring the file to SFTP server, -Path $f -Destination $FILE_PATH_TARGET"

            try {

                # Validate XML and calculate the remote target name before upload.
                # Unknown sellers or invalid XML files are therefore not uploaded.
                $xmlRenamePlan = $null
                if ($extn -ieq ".xml") {
                    $xmlRenamePlan = Get-SftpXmlRenamePlan `
                        -LocalFile $srcFile `
                        -RemoteDirectory $FILE_PATH_TARGET
                }

                # Wichtig: -ErrorAction Stop, damit Fehler wirklich in Catch landen
                Set-SFTPItem `
                    -SFTPSession $global:SFTPSession `
                    -Path $f `
                    -Destination $FILE_PATH_TARGET `
                    -Force `
                    -ErrorAction Stop

                Write-Host "File successfully transferred: $f"
                addLog "File successfully transferred: $f"

                # Rename the uploaded XML file directly on the SFTP server.
                # This runs before the optional local DELETE/RENAME_EXT action.
                if ($null -ne $xmlRenamePlan) {
                    Invoke-SftpXmlRename -RenamePlan $xmlRenamePlan
                }

                switch ($AFTER_COPY_ACTION.ToUpper()) {

                    "DELETE" {

                        Remove-Item -Path $f -Force -ErrorAction Stop

                        Write-Host "Source file deleted: $f"
                        addLog "Source file deleted: $f"
                    }

                    "RENAME_EXT" {

                        if ([string]::IsNullOrWhiteSpace($AFTER_COPY_NEW_EXT)) {
                            throw "AFTER_COPY_NEW_EXT is empty. Please define a new file extension, e.g. '.done'."
                        }

                        if (-not $AFTER_COPY_NEW_EXT.StartsWith(".")) {
                            $AFTER_COPY_NEW_EXT = "." + $AFTER_COPY_NEW_EXT
                        }

                        $directory = $srcFile.DirectoryName
                        $fileNameWithoutExt = [IO.Path]::GetFileNameWithoutExtension($srcFile.Name)
                        $newFileName = $fileNameWithoutExt + $AFTER_COPY_NEW_EXT
                        $newFilePath = Join-Path $directory $newFileName

                        Rename-Item -Path $f -NewName $newFileName -Force -ErrorAction Stop

                        Write-Host "Source file renamed: $f -> $newFilePath"
                        addLog "Source file renamed: $f -> $newFilePath"
                    }

                    "NONE" {

                        Write-Host "No source file action executed for: $f"
                        addLog "No source file action executed for: $f"
                    }

                    default {

                        throw "Invalid AFTER_COPY_ACTION value: '$AFTER_COPY_ACTION'. Allowed values: NONE, DELETE, RENAME_EXT."
                    }
                }

            } catch {

                Write-Host "ERROR while processing file: $f"
                Write-Host $_.Exception.Message

                addLog "ERROR while processing file: $f"
                addLog $_.Exception.Message
            }
        }
    }

    # Show details just to check it
    $FilesMaster = Get-SFTPChildItem -SFTPSession $global:SFTPSession -Path $FILE_PATH_TARGET |
        Where-Object {
            $_.IsDirectory -eq $false -and $_.Name -clike $FILE_CLIKE
        }

    $FilesMaster | Format-Table Name, Length, LastWriteTime

} catch {

    Write-Host $_.Exception.Message
    addLog $_.Exception.Message
}

if (!$?) {
    Write-Host ("ERROR: " + $error[0].Exception.Message)
}
