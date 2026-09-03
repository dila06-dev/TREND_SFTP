# 02 – Installation und Konfiguration

[Zurück zur Übersicht](README.md)

## 1. Voraussetzungen

### 1.1 Betriebssystem und PowerShell

- Windows Server oder Windows Client mit **Windows PowerShell 5.1**;
- Zugriff auf `D:\TREND_SFTP`;
- Leserechte auf den konfigurierten UNC-Freigaben;
- ausgehende TCP-Verbindung zu den SFTP-Hosts und Ports;
- Berechtigung zum Schreiben in `D:\TREND_SFTP\Log`;
- Windows-Konto für die geplanten Tasks.

Das Paket fordert über `#Requires -Version 5.1` mindestens PowerShell 5.1 an.
Es ist für `powershell.exe` ausgelegt, nicht zwingend für `pwsh.exe`.

### 1.2 Posh-SSH

Das Modul muss im Kontext des Scheduler-Kontos oder systemweit verfügbar sein.
Die PowerShell Gallery weist Posh-SSH 3.2.7 als stabile Version aus
(Stand dieser Dokumentation). Beispiel für eine systemweite Installation in
einer administrativen PowerShell:

```powershell
Install-Module -Name Posh-SSH -RequiredVersion 3.2.7 -Scope AllUsers
```

Vorhandene Installation prüfen:

```powershell
Get-Module -ListAvailable -Name Posh-SSH |
    Sort-Object Version -Descending |
    Select-Object -First 1 Name, Version, ModuleBase
```

Die Lösung benötigt folgende Befehle:

```powershell
'New-SFTPSession',
'Remove-SFTPSession',
'Set-SFTPItem',
'Move-SFTPItem',
'Test-SFTPPath' |
    ForEach-Object { Get-Command $_ -ErrorAction Stop }
```

### 1.3 Netzwerkprüfung

Die Erreichbarkeit kann vor einem Produktivlauf geprüft werden:

```powershell
Test-NetConnection www143.your-server.de       -Port 22
Test-NetConnection ftp.digitecgalaxus.ch       -Port 22
Test-NetConnection files.competec.ch            -Port 22
Test-NetConnection dometicsftpqa.blob.core.windows.net -Port 22
```

`TcpTestSucceeded = True` bestätigt nur die TCP-Erreichbarkeit. Benutzer,
Kennwort, SSH-Algorithmen, Hostkey und Remote-Verzeichnis werden dadurch noch
nicht geprüft.

## 2. Soll-Verzeichnisstruktur

```text
D:\TREND_SFTP\
├── MAIN.ps1
├── USER_PARAM.ps1
├── Configuration.ps1
├── Cred.ps1
├── NetworkDrive.ps1
├── PageroXml.ps1
├── SftpTransfer.ps1
├── Utils.ps1
├── TEST_PACKAGE.ps1
├── TEST_PAGERO_XML.ps1
├── README.md
├── Log\
│   ├── transfer.log
│   └── transfer.lock
└── secure\
    ├── trend.sec
    ├── schlanser.sec
    ├── digitecgalaxus.sec
    ├── brack.sec
    └── pagero2.sec
```

Die Log- und Lock-Dateien werden bei Bedarf automatisch angelegt. Die
Credential-Dateien müssen vor dem ersten Lauf vorhanden sein.

## 3. Deployment

### 3.1 Bestehende Installation sichern

Vor dem Austausch:

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = "D:\TREND_SFTP_BACKUP_$stamp"

Copy-Item -LiteralPath 'D:\TREND_SFTP' -Destination $backup -Recurse
Write-Host "Backup: $backup"
```

Prüfen, dass die Sicherung die alten Skripte, `USER_PARAM*.ps1`, Logdatei und
den Ordner `secure` enthält. Das Backup geschützt aufbewahren.

### 3.2 Skripte installieren

1. ZIP-Paket in ein temporäres Verzeichnis entpacken.
2. Alle `.ps1`-Dateien nach `D:\TREND_SFTP` kopieren.
3. Den vorhandenen Ordner `D:\TREND_SFTP\secure` nicht überschreiben.
4. `USER_PARAM.ps1` mit den produktiven Angaben abgleichen.
5. Alte Main-Varianten und `USER_PARAM_2.ps1` nicht mehr im Scheduler aufrufen.

Nach dem Kopieren kann Windows heruntergeladene Dateien blockieren. Das Paket
nur dann entsperren, wenn Quelle und Prüfsumme geprüft wurden:

```powershell
Get-ChildItem 'D:\TREND_SFTP' -Filter '*.ps1' -File | Unblock-File
```

### 3.3 Basistest

```powershell
Set-Location 'D:\TREND_SFTP'
.\TEST_PACKAGE.ps1
.\MAIN.ps1 -ListCustomers
.\MAIN.ps1 -RunProfile HOURLY -ValidateOnly
.\MAIN.ps1 -RunProfile DAILY  -ValidateOnly
```

Erst wenn diese Prüfungen erfolgreich sind, einen produktiven Transfer starten.

## 4. Credential-Dateien

### 4.1 Funktionsprinzip

Die Kennwörter werden nicht im Klartext in `USER_PARAM.ps1` gespeichert. Eine
Credential-Datei enthält die Ausgabe von `ConvertFrom-SecureString` ohne
zusätzlichen Schlüssel. Unter Windows verwendet PowerShell dabei den Schutz des
Windows-Benutzerprofils. Deshalb gilt:

> [!CAUTION]
> `.sec`-Dateien auf dem Zielserver mit genau dem Windows-Konto erzeugen, das
> den geplanten Task ausführt. Kopien auf einen anderen Server oder die Nutzung
> unter einem anderen Benutzerkonto sind normalerweise nicht entschlüsselbar.

`Cred.ps1` entfernt beim Einlesen äußere Leerzeichen und abschließende
Zeilenumbrüche. Dadurch funktionieren Dateien, die mit `Out-File` oder
`Set-Content` geschrieben wurden.

### 4.2 Credential-Datei erzeugen oder erneuern

PowerShell als Scheduler-Konto öffnen:

```powershell
function Save-SecurePasswordFile {
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Prompt
    )

    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $directory -Force | Out-Null

    Read-Host $Prompt -AsSecureString |
        ConvertFrom-SecureString |
        Set-Content -LiteralPath $Path -Encoding UTF8
}
```

Dann die benötigte Datei erzeugen:

```powershell
Save-SecurePasswordFile `
    -Path 'D:\TREND_SFTP\secure\trend.sec' `
    -Prompt 'Kennwort für den SMB-Benutzer Bari'

Save-SecurePasswordFile `
    -Path 'D:\TREND_SFTP\secure\pagero2.sec' `
    -Prompt 'SFTP-Kennwort für PAGERO'
```

Für DAILY entsprechend `schlanser.sec`, `digitecgalaxus.sec` und `brack.sec`
erzeugen. Die Zuordnung steht in `USER_PARAM.ps1`.

Direkter Entschlüsselungstest über die Paketfunktion:

```powershell
Set-Location 'D:\TREND_SFTP'
. .\Cred.ps1

New-SecureCredential `
    -Username 'Bari' `
    -EncryptedPasswordFile '.\secure\trend.sec' |
    Select-Object UserName
```

Das Kennwort wird dabei nicht angezeigt.

### 4.3 Dateirechte einschränken

Beispiel mit Platzhalter für das Scheduler-Konto:

```powershell
$taskAccount = 'DOMETIC\svc_trend_sftp'
$securePath = 'D:\TREND_SFTP\secure'

icacls $securePath /inheritance:r
icacls $securePath /grant:r "${taskAccount}:(OI)(CI)F" 'BUILTIN\Administrators:(OI)(CI)F'
```

Die Änderung ersetzt Berechtigungen. Vorher aktuelle ACLs mit
`icacls D:\TREND_SFTP\secure` dokumentieren und das tatsächliche Servicekonto
einsetzen.

## 5. Allgemeine Konfiguration

Aktuelle Werte aus `USER_PARAM.ps1`:

| Parameter | Aktueller Wert | Bedeutung |
| --- | --- | --- |
| `LogFile` | `D:\TREND_SFTP\Log\transfer.log` | technisches Protokoll |
| `LockFile` | `D:\TREND_SFTP\Log\transfer.lock` | verhindert parallele Läufe |
| `SourceDriveName` | `TREND_SRC` | temporäres PowerShell-Laufwerk ohne Doppelpunkt |
| `NetworkUsername` | `Bari` | SMB-Benutzer für alle Quellfreigaben |
| `NetworkCredentialFile` | `secure\trend.sec` | verschlüsseltes SMB-Kennwort |
| `ConnectionTimeoutSeconds` | `30` | Zeitlimit für Verbindungsaufbau |
| `OperationTimeoutSeconds` | `120` | Zeitlimit für SFTP-Operationen |
| `KeepAliveSeconds` | `15` | Keepalive-Intervall der SFTP-Session |

## 6. Kundenkonfiguration

| Feld | Pflicht | Beschreibung |
| --- | --- | --- |
| `CustomerId` | ja | eindeutige interne Kunden-ID |
| `Enabled` | ja | `$true` aktiviert, `$false` deaktiviert |
| `RunProfile` | ja | `HOURLY` oder `DAILY` |
| `ProcessingMode` | ja | `STANDARD` oder nur bei PAGERO `PAGERO_XML_RENAME` |
| `Host` | ja | DNS-Name oder IP des SFTP-Servers |
| `Port` | ja | SFTP-Port, normalerweise 22 |
| `Username` | ja | SFTP-Benutzername |
| `CredentialFile` | ja | Pfad zur passenden `.sec`-Datei |
| `SourcePath` | ja | UNC-Quellverzeichnis |
| `RemoteDirectory` | ja | absoluter SFTP-Pfad, beginnend mit `/` |
| `FilePattern` | ja | Wildcard zur Vorauswahl, z. B. `*.xml` |
| `FileExtension` | ja | zusätzliche Erweiterungsprüfung, z. B. `.xml` |
| `MinimumFileAgeSeconds` | ja | Mindestalter vor Verarbeitung |
| `AcceptNewHostKey` | ja | steuert `-AcceptKey` bzw. `-ErrorOnUntrusted` |
| `AfterCopyAction` | ja | `NONE`, `DELETE` oder `RENAME_EXT` |
| `AfterCopyNewExtension` | bedingt | erforderlich bei `RENAME_EXT` |
| `SellerEntityMapping` | Pagero | Hashtable Verkäufername → Entity |

### 6.1 Aktuelle produktive Zuordnung

| Kunde | Quelle | Muster | Credential | Host | Ziel |
| --- | --- | --- | --- | --- | --- |
| SCHLANSER | `\\S105DD7A.dometic.internal\SCHLANSER` | `SCHLANSERout_*.csv` | `schlanser.sec` | `www143.your-server.de` | `/` |
| GALAXUS | `\\S105DD7A.dometic.internal\GALAXUSI` | `GALAXI_OUT_*.csv` | `digitecgalaxus.sec` | `ftp.digitecgalaxus.ch` | `/StockData_EU` |
| BRACK | `\\S105DD7A.dometic.internal\BRACK` | `BRACKout_*.csv` | `brack.sec` | `files.competec.ch` | `/pricelistimport` |
| PAGERO | `\\S105DD7A.dometic.internal\TREND\echt\e-Rechnungen` | `*.xml` | `pagero2.sec` | `dometicsftpqa.blob.core.windows.net` | `/in` |

## 7. Pagero-Mapping erweitern

Die Schlüssel müssen fachlich dem Inhalt von `SellerTradeParty/Name`
entsprechen. Die normale PowerShell-Hashtable vergleicht dabei ohne Beachtung
der Groß-/Kleinschreibung. Interpunktion und abweichende Namensbestandteile
bleiben relevant; äußere Leerzeichen werden beim Einlesen entfernt.

```powershell
SellerEntityMapping = @{
    'Dometic Benelux B.V.' = 'DE13'

    # Nur Beispiel – erst nach fachlicher Freigabe aktivieren:
    # 'Weiterer juristischer Verkäufername' = 'ENTITY'
}
```

Erlaubte Zeichen für die Entity sind Buchstaben, Ziffern, Unterstrich und
Bindestrich. Nach jeder Änderung:

```powershell
.\MAIN.ps1 -RunProfile HOURLY -ValidateOnly
.\TEST_PAGERO_XML.ps1 -XmlPath 'D:\Temp\Beispiel.xml'
```

## 8. Standardkunden hinzufügen

Einen vorhandenen `STANDARD`-Block kopieren und alle Werte kontrollieren. Die
Pagero-Sonderlogik darf nicht für andere Kunden verwendet werden.

```powershell
[PSCustomObject]@{
    CustomerId            = 'NEUKUNDE'
    Enabled               = $false       # erst nach Test aktivieren
    RunProfile            = 'DAILY'
    ProcessingMode        = 'STANDARD'
    Host                  = 'sftp.example.invalid'
    Port                  = 22
    Username              = 'sftp-user'
    CredentialFile        = Join-Path $secureDirectory 'neukunde.sec'
    SourcePath            = '\\server\share'
    RemoteDirectory       = '/incoming'
    FilePattern           = 'EXPORT_*.csv'
    FileExtension         = '.csv'
    MinimumFileAgeSeconds = 60
    AcceptNewHostKey      = $false
    AfterCopyAction       = 'RENAME_EXT'
    AfterCopyNewExtension = '.done'
    SellerEntityMapping   = $null
}
```

## 9. Hostkey-Vertrauen

`New-SFTPSession` verwendet eine benutzerspezifische Liste vertrauenswürdiger
SSH-Hosts. Bei `AcceptNewHostKey = $true` übergibt das Skript `-AcceptKey`; ein
bislang unbekannter Fingerprint wird damit automatisch aufgenommen. Ein bereits
gespeicherter, später geänderter Hostkey bleibt ein Fehler, bis die Änderung
extern bestätigt und der gespeicherte Eintrag kontrolliert aktualisiert wurde.

Empfohlenes Verfahren:

1. Fingerprint über einen zweiten, vertrauenswürdigen Kanal vom SFTP-Betreiber
   bestätigen lassen.
2. Erstverbindung unter dem Scheduler-Konto durchführen.
3. Verbose-Ausgabe und bestätigten Fingerprint im Change-Ticket dokumentieren.
4. Danach `AcceptNewHostKey = $false` verwenden, sofern der betriebliche Ablauf
   dies zulässt.
5. Niemals `-Force` ergänzen; dieser Parameter deaktiviert die Hostkey-Prüfung.

## 10. Konfigurationsvalidierung

`Assert-TransferConfiguration` prüft unter anderem:

- alle Pflichtfelder vorhanden;
- Kunden-ID nicht leer und nicht doppelt;
- Profil nur `HOURLY` oder `DAILY`;
- Verarbeitungsmodus nur `STANDARD` oder `PAGERO_XML_RENAME`;
- Pagero-Modus ausschließlich für `CustomerId = 'PAGERO'`;
- Pagero-Erweiterung `.xml` und nicht leeres Mapping;
- Remote-Verzeichnis beginnt mit `/`;
- Dateierweiterung beginnt mit `.`;
- gültige `AfterCopyAction` und Erweiterung bei `RENAME_EXT`.
- jeder aktivierte Kunde verwendet zwingend `RENAME_EXT` mit der Erweiterung
  `.done`.

## 11. Lokale `.done`-Verarbeitung

Für alle aktuell aktivierten Kunden gilt:

```powershell
AfterCopyAction       = 'RENAME_EXT'
AfterCopyNewExtension = '.done'
```

Die Erweiterung wird ersetzt, nicht angehängt:

| Vor Verarbeitung | Nach Verarbeitung |
| --- | --- |
| `2026600172.xml` | `2026600172.done` |
| `GALAXI_OUT_2026090380650.csv` | `GALAXI_OUT_2026090380650.done` |
| `BRACKout_20260902194516.csv` | `BRACKout_20260902194516.done` |

Die lokale Umbenennung erfolgt erst nach bestätigter Remote-Verarbeitung:

- `STANDARD`: nach erfolgreichem `Set-SFTPItem`;
- `PAGERO_XML_RENAME`: nach erfolgreichem Upload und Remote-Rename;
- PAGERO `AlreadyExists`: wenn der deterministische endgültige Remote-Pfad
  bereits existiert.

Existiert die `.done`-Datei bereits, wird sie aus Sicherheitsgründen nicht
überschrieben. Der Vorgang erhält `Failed +1`; der vorhandene Nachweis bleibt
unverändert.

Die Validierung verhindert damit, dass die Pagero-Umbenennung versehentlich
einem Standardkunden zugeordnet wird.
