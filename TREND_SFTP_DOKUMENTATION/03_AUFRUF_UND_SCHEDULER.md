# 03 – Aufruf und Scheduler-Betrieb

[Zurück zur Übersicht](README.md)

## 1. Einstiegspunkt

Alle Ausführungen verwenden ausschließlich:

```text
D:\TREND_SFTP\MAIN.ps1
```

Die alte Variante `MAIN_MINUTE.ps1` und direkte Aufrufe von
`USER_PARAM2.ps1`/`USER_PARAM_2.ps1` sind nicht mehr Bestandteil des Ablaufs.
`USER_PARAM.ps1` ist eine Konfigurationsdatei und wird nicht direkt vom
Scheduler gestartet.

Nach einer bestätigten erfolgreichen Verarbeitung ersetzt das Skript bei allen
Kunden die lokale Dateierweiterung durch `.done`. `Skipped`- und
fehlgeschlagene Dateien behalten ihre ursprüngliche Erweiterung und können in
einem späteren Lauf erneut geprüft werden. Bei Pagero gilt ein bereits
vorhandenes endgültiges Remote-Ziel (`AlreadyExists`) als abgearbeitet und löst
ebenfalls die lokale `.done`-Umbenennung aus.

## 2. Parameter von MAIN.ps1

| Parameter | Typ | Standard | Wirkung |
| --- | --- | --- | --- |
| `-RunProfile` | `HOURLY`, `DAILY`, `ALL` | `HOURLY` | wählt alle aktiven Kunden des Profils |
| `-Customer` | Text, kommasepariert | leer | wählt explizite Kunden und überschreibt `RunProfile` |
| `-ListCustomers` | Switch | aus | zeigt Konfiguration, baut keine Verbindung auf |
| `-ValidateOnly` | Switch | aus | prüft Konfiguration, Posh-SSH und benötigte Credentials ohne Verbindung |

## 3. Aufrufvarianten

### 3.1 Stündlicher Pagero-Lauf

```powershell
Set-Location 'D:\TREND_SFTP'
.\MAIN.ps1 -RunProfile HOURLY
```

Auswahl: PAGERO. Der XML-Inhalt wird ausgewertet und die Zieldatei in `/in`
nach dem Entity-Schema benannt.

### 3.2 Täglicher Standardlauf

```powershell
.\MAIN.ps1 -RunProfile DAILY
```

Auswahl und Reihenfolge: SCHLANSER, GALAXUS, BRACK. Jeder Kunde erhält eine
eigene Session. Ein Kundenfehler beendet nicht automatisch die nachfolgenden
Kunden; der Gesamtlauf liefert dann Exitcode `1`.

### 3.3 Alle aktiven Kunden

```powershell
.\MAIN.ps1 -RunProfile ALL
```

Dieser Aufruf kann Dateien für alle vier Kunden übertragen. Er ist für
kontrollierte Wartungs- oder Abnahmeläufe gedacht, nicht als notwendiger dritter
Scheduler-Task.

### 3.4 Einzelner Kunde

```powershell
.\MAIN.ps1 -Customer PAGERO
.\MAIN.ps1 -Customer GALAXUS
```

Sobald `-Customer` gesetzt ist, wird `-RunProfile` für die Kundenauswahl
ignoriert. Ein expliziter Kunde kann damit unabhängig von seinem Profil
gestartet werden.

### 3.5 Mehrere bestimmte Kunden

```powershell
.\MAIN.ps1 -Customer 'SCHLANSER,BRACK'
```

Leerzeichen um die Kommas werden entfernt; doppelte IDs werden zusammengefasst.

### 3.6 Konfiguration anzeigen

```powershell
.\MAIN.ps1 -ListCustomers
```

Keine Modul-, Credential-, SMB- oder SFTP-Prüfung. Geeignet für eine schnelle
Kontrolle von Aktivierung, Profil, Modus, Host und Remote-Verzeichnis.

### 3.7 Validierung ohne Verbindung

```powershell
.\MAIN.ps1 -RunProfile HOURLY -ValidateOnly
.\MAIN.ps1 -RunProfile DAILY  -ValidateOnly
.\MAIN.ps1 -Customer PAGERO    -ValidateOnly
```

Geprüft werden:

- Struktur und Werte der Konfiguration;
- Import des Moduls Posh-SSH;
- Vorhandensein aller benötigten Posh-SSH-Befehle;
- Entschlüsselbarkeit von `trend.sec`;
- Entschlüsselbarkeit der Credentials der ausgewählten Kunden.

Nicht geprüft werden Netzwerk, UNC-Erreichbarkeit, Anmeldung, Hostkey,
Remote-Verzeichnis oder Schreibrechte auf dem SFTP-Ziel.

## 4. Auswahlmatrix

| Befehl | PAGERO | SCHLANSER | GALAXUS | BRACK | Externe Wirkung |
| --- | :---: | :---: | :---: | :---: | --- |
| `MAIN.ps1` | ✓ | – | – | – | produktiv |
| `MAIN.ps1 -RunProfile HOURLY` | ✓ | – | – | – | produktiv |
| `MAIN.ps1 -RunProfile DAILY` | – | ✓ | ✓ | ✓ | produktiv |
| `MAIN.ps1 -RunProfile ALL` | ✓ | ✓ | ✓ | ✓ | produktiv |
| `MAIN.ps1 -Customer PAGERO` | ✓ | – | – | – | produktiv |
| `MAIN.ps1 -Customer 'SCHLANSER,BRACK'` | – | ✓ | – | ✓ | produktiv |
| `MAIN.ps1 -ListCustomers` | – | – | – | – | keine Verbindung |
| `MAIN.ps1 -RunProfile HOURLY -ValidateOnly` | prüft | – | – | – | keine Verbindung |
| `MAIN.ps1 -RunProfile DAILY -ValidateOnly` | – | prüft | prüft | prüft | keine Verbindung |

## 5. Windows Task Scheduler

### 5.1 Stündlicher Task

| Feld | Wert |
| --- | --- |
| Name | `TREND SFTP - HOURLY - PAGERO` |
| Programm/Skript | `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` |
| Argumente | `-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "D:\TREND_SFTP\MAIN.ps1" -RunProfile HOURLY` |
| Starten in | `D:\TREND_SFTP` |
| Trigger | stündlich, gewünschte Startminute |
| Konto | dasselbe Konto, das die `.sec`-Dateien erzeugt hat |

### 5.2 Täglicher Task

| Feld | Wert |
| --- | --- |
| Name | `TREND SFTP - DAILY - STANDARD` |
| Programm/Skript | `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` |
| Argumente | `-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "D:\TREND_SFTP\MAIN.ps1" -RunProfile DAILY` |
| Starten in | `D:\TREND_SFTP` |
| Trigger | täglich nach Bereitstellung der CSV-Dateien |
| Konto | dasselbe Konto, das die `.sec`-Dateien erzeugt hat |

### 5.3 Empfohlene Task-Einstellungen

- „Unabhängig von der Benutzeranmeldung ausführen“;
- Kennwort des Servicekontos im Task hinterlegen;
- „Task so schnell wie möglich nach einem verpassten Start ausführen“;
- keine zweite Instanz starten, wenn der Task bereits läuft;
- Ausführung nach einem geeigneten betrieblichen Zeitlimit beenden;
- Verlauf aktivieren;
- Rückgabecode und `transfer.log` überwachen.

Die Skript-Lockdatei schützt zusätzlich, falls zwei unterschiedliche Tasks oder
manuelle Starts zeitlich kollidieren.

## 6. Task mit PowerShell registrieren

Das folgende Beispiel erzeugt den stündlichen Task. Kontoname, Startzeit und
Ausführungsrichtlinie vor Verwendung abstimmen. `Register-ScheduledTask` fragt
je nach Sicherheitskontext nach dem Kennwort des Task-Kontos.

```powershell
$action = New-ScheduledTaskAction `
    -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
    -Argument '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "D:\TREND_SFTP\MAIN.ps1" -RunProfile HOURLY' `
    -WorkingDirectory 'D:\TREND_SFTP'

$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).Date.AddHours(1) `
    -RepetitionInterval (New-TimeSpan -Hours 1) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 45)

Register-ScheduledTask `
    -TaskName 'TREND SFTP - HOURLY - PAGERO' `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description 'Stündlicher Pagero XML Transfer'
```

Das Codebeispiel legt einen Wiederholungszeitraum von zehn Jahren an. Für einen
zeitlich unbegrenzten Betrieb den Trigger in der Aufgabenplanung entsprechend
setzen und in das reguläre Task-Review aufnehmen.

In produktiven Domänenumgebungen ist die Registrierung über die grafische
Aufgabenplanung oft transparenter, weil dort Konto, Kennwort und Option
„Unabhängig von der Benutzeranmeldung“ gemeinsam festgelegt werden können.

## 7. Task prüfen und manuell auslösen

```powershell
$taskName = 'TREND SFTP - HOURLY - PAGERO'

Get-ScheduledTask -TaskName $taskName |
    Select-Object TaskName, State

Get-ScheduledTaskInfo -TaskName $taskName |
    Select-Object LastRunTime, LastTaskResult, NextRunTime

Start-ScheduledTask -TaskName $taskName
```

Nach dem Start zusätzlich prüfen:

```powershell
Get-Content 'D:\TREND_SFTP\Log\transfer.log' -Tail 100
```

`LastTaskResult = 0` bedeutet Erfolg. Die Skriptcodes `1` und `2` sind in
Abschnitt 9 beschrieben.

## 8. Protokoll und Konsolenausgabe

Logformat:

```text
yyyy-MM-dd HH:mm:ss.fff [LEVEL] [CUSTOMER] Nachricht
```

Beispiele:

```text
2026-09-03 09:00:00.123 [INFO] [-] Run started. Profile=HOURLY; Customer=; Selected=PAGERO
2026-09-03 09:00:02.456 [INFO] [PAGERO] Uploaded '2026600172.xml' as 'DE13-Invoice-2026600172-...xml'; Seller='Dometic Benelux B.V.'; Entity='DE13'.
2026-09-03 09:00:03.000 [INFO] [-] Run finished. ExitCode=0
```

Die Abschlussübersicht enthält je Kunde `Uploaded`, `AlreadyExists`, `Skipped`,
`Failed` und `Status`.

## 9. Rückgabecodes für Monitoring

| Code | Bedeutung | Empfohlene Reaktion |
| --- | --- | --- |
| `0` | vollständig verarbeitet oder nur erwartete Skips/Dubletten | keine Alarmierung |
| `1` | mindestens eine Datei oder ein Kunde fehlgeschlagen; im Produktivlauf auch bei kundenspezifischem Credential-/Verbindungsfehler | Log prüfen, Ticket/Alarm |
| `2` | Lauf konnte wegen Initialisierung, Konfiguration, Modul, Lock oder fehlgeschlagener Credential-Prüfung bei `-ValidateOnly` nicht beginnen | sofort prüfen; Scheduler-/Deploymentfehler möglich |

PowerShell-Prozesscode nach einem manuellen Lauf:

```powershell
.\MAIN.ps1 -RunProfile HOURLY
$LASTEXITCODE
```

## 10. Empfohlener manueller Ablauf

```powershell
Set-Location 'D:\TREND_SFTP'

# Konfiguration ansehen
.\MAIN.ps1 -ListCustomers

# Betroffenes Profil ohne Verbindung validieren
.\MAIN.ps1 -RunProfile HOURLY -ValidateOnly

# Erst danach produktiv ausführen
.\MAIN.ps1 -RunProfile HOURLY

# Ergebnis sichern
$code = $LASTEXITCODE
Get-Content '.\Log\transfer.log' -Tail 100
Write-Host "Exitcode: $code"
```
