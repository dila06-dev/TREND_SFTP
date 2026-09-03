# 06 – Fehlerbehebung

[Zurück zur Übersicht](README.md)

## 1. Empfohlene Diagnose-Reihenfolge

Bei einem Fehler nicht sofort Credentials, Hostkeys oder produktive Dateien
ändern. In dieser Reihenfolge prüfen:

1. Konsolenausgabe und Exitcode sichern.
2. Letzte 100 Zeilen aus `Log\transfer.log` lesen.
3. `TEST_PACKAGE.ps1` ausführen.
4. `MAIN.ps1 -ListCustomers` prüfen.
5. Betroffenen Kunden mit `-ValidateOnly` prüfen.
6. Host und TCP-Port mit `Test-NetConnection` prüfen.
7. Erst danach SMB-Zugriff, SFTP-Anmeldung, Hostkey und Remote-Pfad untersuchen.

```powershell
Set-Location 'D:\TREND_SFTP'

.\TEST_PACKAGE.ps1
.\MAIN.ps1 -ListCustomers
.\MAIN.ps1 -Customer PAGERO -ValidateOnly

Get-Content '.\Log\transfer.log' -Tail 100
```

## 2. Fehlerübersicht

| Meldung/Symptom | Wahrscheinliche Ursache | Erste Maßnahme |
| --- | --- | --- |
| `USER_PARAM2.ps1 is not recognized` | alter relativer Skriptaufruf | Scheduler auf neue `MAIN.ps1` umstellen |
| `Input string was not in a correct format` | alte Credential-Leselogik oder ungültiger Dateiinhalt | aktuelle `Cred.ps1` einsetzen, `-ValidateOnly` |
| `cannot be decrypted by the current Windows account` | anderes Konto/anderer Server oder beschädigte `.sec` | Datei unter Scheduler-Konto neu erzeugen |
| `Encrypted credential file not found` | falscher Pfad/fehlende Datei | `CredentialFile` und `secure` prüfen |
| `Required Posh-SSH command ... is not available` | fehlendes/falsches Modul | Posh-SSH-Installation prüfen |
| `Key exchange negotiation failed` | keine gemeinsame SSH-Algorithmus-Auswahl | Modulversion und Serveralgorithmen abstimmen |
| `Fingerprint not matched` | Hostkey wurde geändert | Fingerprint extern bestätigen, dann kontrolliert aktualisieren |
| `Remote directory ... does not exist` | falscher Pfad oder fehlende Rechte | erst Session prüfen, dann Pfad/Rechte |
| `Mounted source path is not accessible` | UNC, DNS, SMB oder Berechtigung | Zugriff als Scheduler-Konto testen |
| `PowerShell drive 'TREND_SRC' already exists` | fremdes/altes PSDrive im Prozess | Prozess und Laufzustand prüfen |
| `Another transfer run is already active` | paralleler Lauf hält Lock | laufenden Task identifizieren und abwarten |
| `No Pagero entity mapping exists` | Verkäufer nicht konfiguriert | XML-Wert fachlich prüfen und Mapping ergänzen |
| `SellerTradeParty/Name not found` | XML-Struktur unvollständig/abweichend | XML gegen erwarteten Pfad prüfen |
| `too new or locked` | Datei jünger als Mindestalter oder noch geschrieben | warten und nächsten Lauf nutzen |
| `target already exists` | identische Pagero-Datei bereits übertragen | erwartete Dublettenvermeidung |
| `Local post-transfer target already exists` | gleichnamige `.done`-Datei liegt bereits in der Quelle | Dateien vergleichen und vorhandenen Nachweis kontrolliert archivieren |

## 3. Alter Skriptpfad USER_PARAM2.ps1

### Meldung

```text
..\SFTP\USER_PARAM2.ps1 : The term ... is not recognized
```

### Ursache

Ein alter Main-/Minute-Job verweist noch relativ auf eine zweite
Parameterdatei. Diese Architektur wurde ersetzt.

### Lösung

Scheduler-Aktion auf einen der beiden zentralen Aufrufe setzen:

```text
-File "D:\TREND_SFTP\MAIN.ps1" -RunProfile HOURLY
-File "D:\TREND_SFTP\MAIN.ps1" -RunProfile DAILY
```

Danach in der Aufgabenplanung prüfen, dass kein aktiver Task mehr
`MAIN_MINUTE.ps1`, `USER_PARAM2.ps1` oder `USER_PARAM_2.ps1` verwendet.

## 4. Credential-Fehler

### 4.1 `Input string was not in a correct format`

Die ältere Leselogik übergab bei `Get-Content -Raw` auch den von `Out-File`
erzeugten Zeilenumbruch an `ConvertTo-SecureString`. Die aktuelle `Cred.ps1`
verwendet:

```powershell
$encryptedPassword = (
    Get-Content -LiteralPath $EncryptedPasswordFile -Raw -ErrorAction Stop
).Trim()
```

Prüfen, ob diese Zeile in `D:\TREND_SFTP\Cred.ps1` vorhanden ist:

```powershell
Select-String `
    -Path 'D:\TREND_SFTP\Cred.ps1' `
    -Pattern '\.Trim\(\)'
```

Anschließend:

```powershell
.\MAIN.ps1 -Customer PAGERO -ValidateOnly
```

### 4.2 Entschlüsselung unter aktuellem Konto nicht möglich

Wenn der Fehler mit aktueller `Cred.ps1` bestehen bleibt, wurde die `.sec`-Datei
wahrscheinlich unter einem anderen Windows-Benutzer oder auf einem anderen
Computer erzeugt.

Den Task-Benutzer ermitteln. Ein Credential-Fehler ergibt bei `-ValidateOnly`
Exitcode `2`; tritt er erst im produktiven Kundenlauf auf, wird der Kunde als
fehlgeschlagen gezählt und der Gesamtlauf endet mit Exitcode `1`.

```powershell
(Get-ScheduledTask -TaskName 'TREND SFTP - HOURLY - PAGERO').Principal |
    Select-Object UserId, LogonType, RunLevel
```

Als genau dieser Benutzer auf dem Zielserver anmelden und Datei neu erzeugen:

```powershell
Read-Host 'SFTP-Passwort für PAGERO' -AsSecureString |
    ConvertFrom-SecureString |
    Set-Content `
        -LiteralPath 'D:\TREND_SFTP\secure\pagero2.sec' `
        -Encoding UTF8
```

Beachten: `trend.sec` ist das Kennwort für den SMB-Benutzer `Bari`;
`pagero2.sec` ist das Pagero-SFTP-Kennwort. Die Fehlermeldung nennt die konkret
betroffene Datei. Nur diese Datei erneuern.

### 4.3 Sichere Dateiprüfung

Ohne Inhalt oder Kennwort auszugeben:

```powershell
Get-Item 'D:\TREND_SFTP\secure\trend.sec' |
    Select-Object FullName, Length, LastWriteTime

Get-Acl 'D:\TREND_SFTP\secure\trend.sec' |
    Format-List Owner, AccessToString
```

Den Dateiinhalt niemals in ein Ticket, Protokoll oder Chat kopieren.

## 5. Posh-SSH fehlt oder falsche Version

### Meldung

```text
Required Posh-SSH command '...' is not available.
```

### Prüfung

```powershell
Get-Module -ListAvailable Posh-SSH |
    Sort-Object Version -Descending |
    Format-Table Name, Version, ModuleBase

Import-Module Posh-SSH -Verbose
Get-Command -Module Posh-SSH '*SFTP*'
```

Wichtig: Die Prüfung als Scheduler-Konto durchführen. Eine Installation mit
`-Scope CurrentUser` für einen Administrator ist für ein Servicekonto nicht
automatisch sichtbar. Falls zulässig, systemweit installieren:

```powershell
Install-Module Posh-SSH -RequiredVersion 3.2.7 -Scope AllUsers
```

## 6. Hostkey- und SSH-Fehler

### 6.1 Fingerprint stimmt nicht überein

Beispiel:

```text
Fingerprint not matched trusted ... fingerprint
```

Das ist ein Sicherheitsstopp. Nicht `-Force` hinzufügen und nicht ungeprüft die
Hostkey-Datei löschen.

Vorgehen:

1. betroffenen Host und angezeigten Fingerprint dokumentieren;
2. SFTP-Betreiber über einen zweiten Kanal kontaktieren;
3. neuen Fingerprint bestätigen lassen;
4. Change dokumentieren;
5. gespeicherten Eintrag unter dem Scheduler-Konto kontrolliert aktualisieren;
6. Verbindung erneut testen.

Für GALAXUS wurde bereits ein Fingerprint-Konflikt beobachtet. Erst nach
Bestätigung durch Digitec Galaxus aktualisieren.

### 6.2 `Key exchange negotiation failed`

Dieser Fehler entsteht vor Benutzeranmeldung und Remote-Pfadprüfung. Mögliche
Ursachen:

- Server unterstützt nur veraltete oder nicht angebotene Algorithmen;
- Posh-SSH/Renci.SshNet-Version ist zu alt oder inkompatibel;
- SFTP-Endpunkt wurde technisch geändert;
- Sicherheitsrichtlinie des Servers wurde angepasst.

Prüfen:

```powershell
Get-Module -ListAvailable Posh-SSH |
    Sort-Object Version -Descending |
    Select-Object -First 1 Name, Version, ModuleBase

Test-NetConnection ftp.digitecgalaxus.ch -Port 22
```

Die Serveralgorithmen mit dem Betreiber abstimmen. Keine schwachen Algorithmen
ohne Security-Freigabe reaktivieren.

### 6.3 Remote-Pfadfehler nach Verbindungsfehler

In den alten Skripten konnte nach einer fehlgeschlagenen Session zusätzlich die
Meldung erscheinen, `/StockData_EU` existiere nicht. Zuerst immer den
Verbindungs-/Hostkeyfehler lösen. Die vereinheitlichte Version arbeitet je Kunde
mit einer lokalen Sessionvariable und startet den Transfer erst nach einer
erfolgreichen Sessionerstellung.

## 7. SMB- und Quellpfadfehler

### 7.1 Quellfreigabe als Scheduler-Konto prüfen

```powershell
$source = '\\S105DD7A.dometic.internal\TREND\echt\e-Rechnungen'

Test-Path -LiteralPath $source
Get-ChildItem -LiteralPath $source -File |
    Select-Object -First 10 Name, Length, LastWriteTime
```

Wenn der direkte Zugriff mit dem angemeldeten Konto funktioniert, heißt das
nicht zwingend, dass die in `trend.sec` hinterlegten SMB-Zugangsdaten gültig
sind. `-ValidateOnly` prüft lediglich die Entschlüsselung, nicht die Anmeldung
an der Freigabe.

### 7.2 PSDrive ist bereits vorhanden

```powershell
Get-PSDrive -Name TREND_SRC -ErrorAction SilentlyContinue |
    Format-List *
```

In einem neu gestarteten `powershell.exe` sollte dieses temporäre PSDrive nicht
vorhanden sein. Nicht blind entfernen, wenn ein aktiver Transfer läuft. Zuerst
Prozess und Taskstatus prüfen.

## 8. Remote-Verzeichnis fehlt

### Meldung

```text
Remote directory '/StockData_EU' does not exist on 'ftp.digitecgalaxus.ch'.
```

Prüfen:

- war die SFTP-Session wirklich erfolgreich?;
- ist der Pfad absolut und korrekt geschrieben?;
- ist das Login auf ein Chroot-Verzeichnis beschränkt?;
- besitzt der Benutzer Listen- und Schreibrechte?;
- wurde das Zielverzeichnis umbenannt?;
- ist Groß-/Kleinschreibung auf dem Server relevant?

Den Pfad erst nach erfolgreicher Anmeldung bewerten. Änderungen an
`RemoteDirectory` mit dem Partner abstimmen.

## 9. Pagero-XML-Fehler

### 9.1 Verkäufer nicht gemappt

```text
No Pagero entity mapping exists for seller '...'
```

Verkäuferwert lokal ermitteln:

```powershell
[xml]$doc = Get-Content 'D:\Temp\Rechnung.xml' -Raw
$doc.SelectSingleNode(
    "/*[local-name()='CrossIndustryInvoice']" +
    "/*[local-name()='SupplyChainTradeTransaction']" +
    "/*[local-name()='ApplicableHeaderTradeAgreement']" +
    "/*[local-name()='SellerTradeParty']" +
    "/*[local-name()='Name']"
).InnerText
```

Den Namen fachlich bestätigen, Mapping in `USER_PARAM.ps1` ergänzen und mit
`TEST_PAGERO_XML.ps1` prüfen.

### 9.2 SellerTradeParty/Name fehlt

XML-Struktur und Namespace-unabhängigen Pfad prüfen. Ein gleichnamiges
`<ram:Name>` in einem anderen Bereich, etwa Position oder Käufer, wird bewusst
nicht verwendet.

### 9.3 Ziel existiert bereits

```text
Pagero target already exists; upload skipped
```

Das ist normalerweise kein Fehler. Es zeigt, dass dieselbe unveränderte
Quelldatei schon übertragen wurde. Danach wird die lokale `.xml`-Datei auf
`.done` umbenannt. Summary: `AlreadyExists +1`, Status `OK`, sofern die lokale
Umbenennung erfolgreich ist.

Nur wenn eine fachlich neue Datei fälschlich denselben Namen erhält, lokalen
Dateiinhalt und `LastWriteTimeUtc` prüfen.

### 9.4 Lokales `.done`-Ziel existiert bereits

```text
Local post-transfer target already exists: '...\2026600172.done'.
```

Das Skript überschreibt keinen vorhandenen Verarbeitungsnachweis. Ein
Remote-Upload oder ein erkanntes Pagero-`AlreadyExists` kann zu diesem Zeitpunkt
bereits erfolgreich gewesen sein; deshalb Remote- und Lokalzustand gemeinsam
prüfen.

```powershell
$active = '\\server\share\2026600172.xml'
$done   = '\\server\share\2026600172.done'

Get-Item -LiteralPath $active, $done |
    Select-Object FullName, Length, LastWriteTime, LastWriteTimeUtc

Get-FileHash -Algorithm SHA256 -LiteralPath $active, $done
```

Wenn beide Dateien identisch sind, die ältere `.done`-Datei nach betrieblicher
Vorgabe archivieren und den Lauf wiederholen. Sind sie verschieden, nicht
überschreiben: fachlich klären, welche Lieferung verarbeitet wurde und welche
Remote-Datei dazu gehört.

## 10. Datei wird als `Skipped` gezählt

```powershell
$file = Get-Item '\\server\share\datei.xml'

[PSCustomObject]@{
    Name             = $file.Name
    LastWriteTime    = $file.LastWriteTime
    LastWriteTimeUtc = $file.LastWriteTimeUtc
    AgeSeconds       = [math]::Round(((Get-Date) - $file.LastWriteTime).TotalSeconds, 1)
    Length           = $file.Length
}
```

Wenn `AgeSeconds < 60`, nächsten Lauf abwarten. Bei ausreichendem Alter kann ein
anderer Prozess die Datei noch exklusiv geöffnet haben. Die Datei nicht während
des Schreibvorgangs erzwingen.

## 11. Lauf-Sperre

Die bloße Existenz von `transfer.lock` bedeutet nicht, dass ein Lauf aktiv ist.
Die Sperrwirkung entsteht durch den exklusiven offenen Dateihandle.

Taskstatus prüfen:

```powershell
Get-ScheduledTask |
    Where-Object TaskName -like 'TREND SFTP*' |
    Select-Object TaskName, State

Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Select-Object ProcessId, CreationDate, CommandLine
```

Einen Prozess nur beenden, wenn eindeutig feststeht, dass er hängen geblieben
ist und keine SFTP-Operation mehr läuft.

## 12. Diagnosepaket ohne Geheimnisse

Folgende Informationen sind für Support sinnvoll:

```powershell
$diag = 'D:\Temp\TREND_SFTP_DIAG'
New-Item -ItemType Directory -Path $diag -Force | Out-Null

Copy-Item 'D:\TREND_SFTP\Log\transfer.log' $diag
Copy-Item 'D:\TREND_SFTP\USER_PARAM.ps1' $diag

Get-Module -ListAvailable Posh-SSH |
    Select-Object Name, Version, ModuleBase |
    Out-File "$diag\Posh-SSH.txt"

$PSVersionTable |
    Out-String |
    Out-File "$diag\PowerShell.txt"
```

Vor Weitergabe `USER_PARAM.ps1` auf interne Hostnamen, Benutzernamen und Pfade
prüfen. Den Ordner `secure`, `.sec`-Dateien, Kennwörter und Hostkey-Speicher
nicht beilegen.
