# 07 – Betriebshandbuch und Checklisten

[Zurück zur Übersicht](README.md)

## 1. Regelbetrieb

### Stündlicher Pagero-Lauf

- Task: `TREND SFTP - HOURLY - PAGERO`
- Parameter: `-RunProfile HOURLY`
- erwarteter Kunde: PAGERO
- Verarbeitung: XML lesen, Entity ermitteln, Upload nach `/in`, remote umbenennen
- lokale Nachbearbeitung: `.xml` → `.done`
- normaler Exitcode: `0`

### Täglicher Standardlauf

- Task: `TREND SFTP - DAILY - STANDARD`
- Parameter: `-RunProfile DAILY`
- erwartete Kunden: SCHLANSER, GALAXUS, BRACK
- Verarbeitung: Originaldateiname bleibt unverändert
- lokale Nachbearbeitung: `.csv` → `.done`
- normaler Exitcode: `0`

## 2. Tägliche Betriebskontrolle

- [ ] Scheduler-Status beider Tasks ist nicht `Running` über das normale Zeitfenster hinaus
- [ ] `LastTaskResult` ist `0`
- [ ] `transfer.log` enthält `Run finished. ExitCode=0`
- [ ] keine neuen `[ERROR]`-Zeilen
- [ ] `Uploaded`, `AlreadyExists` und `Skipped` sind fachlich plausibel
- [ ] erfolgreich verarbeitete Quelldateien tragen die Erweiterung `.done`
- [ ] keine Fehler wegen bereits vorhandener `.done`-Zieldateien
- [ ] bei Pagero keine unerwarteten Verkäufer-Mappingfehler
- [ ] bei DAILY keine Hostkey- oder Remote-Verzeichnisfehler

Prüfbefehle:

```powershell
Get-ScheduledTask |
    Where-Object TaskName -like 'TREND SFTP*' |
    ForEach-Object {
        $info = $_ | Get-ScheduledTaskInfo
        [PSCustomObject]@{
            TaskName       = $_.TaskName
            State          = $_.State
            LastRunTime    = $info.LastRunTime
            LastTaskResult = $info.LastTaskResult
            NextRunTime    = $info.NextRunTime
        }
    } |
    Format-Table -AutoSize

Get-Content 'D:\TREND_SFTP\Log\transfer.log' -Tail 100
```

## 3. Checkliste vor einer Änderung

- [ ] fachlicher Auftrag und betroffene Kunden dokumentiert
- [ ] Änderung betrifft Pagero oder Standardtransfer eindeutig geklärt
- [ ] Backup von `D:\TREND_SFTP` erstellt
- [ ] aktueller ZIP-/Skriptstand und Prüfsumme dokumentiert
- [ ] Testkopie außerhalb des Produktivverzeichnisses erstellt
- [ ] keine Credential-Datei in Ticket, E-Mail oder Quellcode übernommen
- [ ] Wartungs-/Testfenster abgestimmt
- [ ] Rollback-Pfad bekannt

## 4. Änderung eines Pagero-Mappings

1. Exakten Wert aus `SellerTradeParty/Name` ermitteln.
2. Fachliche Entity bestätigen lassen.
3. Backup von `USER_PARAM.ps1` erstellen.
4. Mapping nur im PAGERO-Block ergänzen.
5. `-ValidateOnly` ausführen.
6. Lokale XML mit `TEST_PAGERO_XML.ps1` prüfen.
7. End-to-End-Test im freigegebenen Ziel durchführen.
8. Wiederholungstest auf `AlreadyExists` durchführen.
9. Änderung, Testdatei, Zielname und Ergebnis dokumentieren.

```powershell
Copy-Item `
    'D:\TREND_SFTP\USER_PARAM.ps1' `
    "D:\TREND_SFTP\USER_PARAM.ps1.$(Get-Date -Format yyyyMMdd-HHmmss).bak"

.\MAIN.ps1 -RunProfile HOURLY -ValidateOnly
.\TEST_PAGERO_XML.ps1 -XmlPath 'D:\Temp\Mappingtest.xml'
```

## 5. Hinzufügen eines Standardkunden

- [ ] neue eindeutige `CustomerId`
- [ ] `ProcessingMode = 'STANDARD'`
- [ ] Profil `HOURLY` oder `DAILY` fachlich festgelegt
- [ ] Credential-Datei unter Scheduler-Konto erzeugt
- [ ] UNC-Pfad und Dateifilter geprüft
- [ ] absoluter SFTP-Pfad geprüft
- [ ] Hostfingerprint extern bestätigt
- [ ] Kunde zunächst `Enabled = $false`
- [ ] Syntax- und Konfigurationsprüfung erfolgreich
- [ ] Testsystem/Quelltest erfolgreich
- [ ] Kunde kontrolliert aktiviert
- [ ] Scheduler-Zuordnung geprüft

## 6. Credential-Wechsel

### Vorbereitung

- [ ] betroffenes Konto und Datei eindeutig zugeordnet
- [ ] neues Kennwort gültig
- [ ] Zugriff als Scheduler-Konto möglich
- [ ] Backup der alten `.sec` geschützt erstellt
- [ ] kein produktiver Lauf während des Wechsels

### Durchführung

1. Als Scheduler-Konto anmelden.
2. Nur die betroffene `.sec`-Datei neu erzeugen.
3. Dateiinhalt nicht anzeigen.
4. Rechte und Dateigröße prüfen.
5. Betroffenen Kunden mit `-ValidateOnly` prüfen.
6. Kontrollierten Produktiv-/Verbindungstest ausführen.
7. Taskstatus und Log prüfen.

### Zuordnung

| Datei | Zweck |
| --- | --- |
| `trend.sec` | SMB-Zugriff über Benutzer `Bari` |
| `schlanser.sec` | SFTP SCHLANSER |
| `digitecgalaxus.sec` | SFTP GALAXUS |
| `brack.sec` | SFTP BRACK |
| `pagero2.sec` | SFTP PAGERO |

## 7. Hostkey-Wechsel

- [ ] Fehler und angezeigten Fingerprint dokumentieren
- [ ] keine Umgehung mit `-Force`
- [ ] SFTP-Betreiber über bekannten zweiten Kanal kontaktiert
- [ ] alter und neuer Fingerprint bestätigt
- [ ] Change/Security-Freigabe vorhanden
- [ ] Aktualisierung unter Scheduler-Konto durchgeführt
- [ ] Testverbindung erfolgreich
- [ ] Remote-Verzeichnis und Schreibrecht geprüft
- [ ] Change mit Datum, Bearbeiter und Nachweis abgeschlossen

## 8. Deployment-Checkliste

- [ ] altes Verzeichnis vollständig gesichert
- [ ] neue Skripte nach `D:\TREND_SFTP` kopiert
- [ ] vorhandener `secure`-Ordner erhalten
- [ ] nur eine aktive `MAIN.ps1` im Scheduler referenziert
- [ ] kein Task verweist auf `MAIN_MINUTE.ps1` oder `USER_PARAM2.ps1`
- [ ] `TEST_PACKAGE.ps1` erfolgreich
- [ ] `-ListCustomers` korrekt
- [ ] HOURLY `-ValidateOnly` erfolgreich
- [ ] DAILY `-ValidateOnly` erfolgreich
- [ ] Pagero-XML-Lokaltest erfolgreich
- [ ] Scheduler-Konto geprüft
- [ ] Startverzeichnis im Scheduler gesetzt
- [ ] produktiver Abnahmelauf erfolgreich
- [ ] Rollback-Backup noch vorhanden

## 9. Rollback

Rollback verwenden, wenn die neue Version nach Deployment nicht innerhalb des
Wartungsfensters stabilisiert werden kann.

1. Beide TREND-SFTP-Tasks deaktivieren.
2. Aktiven PowerShell-Prozess und SFTP-Übertragung prüfen; nicht während eines
   laufenden Uploads überschreiben.
3. Fehlerhafte Version separat sichern.
4. Backup der letzten freigegebenen Version zurückkopieren.
5. Scheduler-Aktionen gegen den wiederhergestellten Einstiegspunkt prüfen.
6. Syntax, Credentials und kontrollierten Lauf testen.
7. Tasks wieder aktivieren.
8. Incident und Rollback dokumentieren.

Beispiel für die Sicherung der fehlerhaften Version:

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Rename-Item `
    -LiteralPath 'D:\TREND_SFTP' `
    -NewName "TREND_SFTP_FAILED_$stamp"

Copy-Item `
    -LiteralPath 'D:\TREND_SFTP_BACKUP_<Zeitstempel>' `
    -Destination 'D:\TREND_SFTP' `
    -Recurse
```

Vor Ausführung den konkreten Backup-Pfad einsetzen und sicherstellen, dass kein
Task läuft.

## 10. Incident-Checkliste

- [ ] Zeitpunkt und Taskname erfasst
- [ ] Exitcode erfasst
- [ ] Konsolenausgabe/Task-History gesichert
- [ ] relevante Logzeilen gesichert
- [ ] betroffener Kunde identifiziert
- [ ] andere Kunden auf Weiterverarbeitung geprüft
- [ ] lokaler Zustand geprüft: aktive `.xml`/`.csv`, erwartete `.done`-Datei und mögliche Kollision
- [ ] Remote-Zustand geprüft: Originalname, Zielname, Dublette
- [ ] Credentials nicht offengelegt
- [ ] Hostkeyänderung nicht ungeprüft akzeptiert
- [ ] Ursache und Korrektur dokumentiert
- [ ] Wiederholungstest erfolgreich
- [ ] Monitoring wieder grün

## 11. Aufbewahrung und Logrotation

Das aktuelle Skript schreibt fortlaufend in `transfer.log`; automatische
Rotation ist nicht implementiert. Daher Größe überwachen und nach betrieblicher
Vorgabe archivieren. Rotation nur durchführen, wenn kein Transfer läuft.

Beispiel für eine manuelle, verlustfreie Archivierung:

```powershell
$log = 'D:\TREND_SFTP\Log\transfer.log'
$archive = 'D:\TREND_SFTP\Log\archive'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

New-Item -ItemType Directory -Path $archive -Force | Out-Null
Copy-Item -LiteralPath $log -Destination "$archive\transfer-$stamp.log"
Clear-Content -LiteralPath $log
```

Vorher sicherstellen, dass kein Task `Running` ist. Langfristig kann eine
automatische Rotation als separate, freigegebene Erweiterung umgesetzt werden.

## 12. Änderungsprotokoll-Vorlage

| Feld | Inhalt |
| --- | --- |
| Change-/Ticketnummer |  |
| Datum/Uhrzeit |  |
| Bearbeiter |  |
| betroffene Datei(en) |  |
| betroffener Kunde/Profil |  |
| Beschreibung vorher |  |
| Beschreibung nachher |  |
| Backup-Pfad |  |
| durchgeführte Tests |  |
| Exitcodes |  |
| Ergebnis |  |
| Rollback erforderlich | ja / nein |
| fachliche Freigabe |  |
