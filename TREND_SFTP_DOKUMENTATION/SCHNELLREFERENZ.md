# TREND-SFTP – Schnellreferenz

[Zurück zur Übersicht](README.md)

## Häufigste Befehle

```powershell
Set-Location 'D:\TREND_SFTP'

# Syntax
.\TEST_PACKAGE.ps1

# Übersicht ohne Verbindung
.\MAIN.ps1 -ListCustomers

# Konfiguration und Credentials ohne Verbindung
.\MAIN.ps1 -RunProfile HOURLY -ValidateOnly
.\MAIN.ps1 -RunProfile DAILY  -ValidateOnly

# Produktiv
.\MAIN.ps1 -RunProfile HOURLY
.\MAIN.ps1 -RunProfile DAILY

# Einzelne Kunden
.\MAIN.ps1 -Customer PAGERO
.\MAIN.ps1 -Customer 'SCHLANSER,BRACK'

# Lokaler Pagero-Test ohne SFTP
.\TEST_PAGERO_XML.ps1 -XmlPath 'D:\Temp\2026600172.xml'

# Lokaler Test der .done-Umbenennung ohne SFTP
.\TEST_AFTER_COPY.ps1

# Rückgabecode und Log
$LASTEXITCODE
Get-Content '.\Log\transfer.log' -Tail 100
```

## Profile

| Profil | Kunden | Verhalten |
| --- | --- | --- |
| `HOURLY` | PAGERO | XML lesen und remote umbenennen |
| `DAILY` | SCHLANSER, GALAXUS, BRACK | Originaldateiname unverändert |
| `ALL` | alle aktiven Kunden | kontrollierter Gesamtlauf |

Nach erfolgreicher Verarbeitung wird die lokale Erweiterung ersetzt:

```text
2026600172.xml -> 2026600172.done
Export.csv     -> Export.done
```

Ein vorhandenes `.done`-Ziel wird nicht überschrieben.

## Pagero-Regel

```text
SellerTradeParty/Name: Dometic Benelux B.V.
Mapping:               DE13
Quelle:                2026600172.xml
Ziel:                  /in/DE13-Invoice-2026600172-<yyyyMMddHHmmssfff>.xml
```

## Exitcodes

| Code | Bedeutung |
| --- | --- |
| `0` | erfolgreich |
| `1` | Kunden- oder Dateifehler; im Produktivlauf auch kundenspezifische Credential-/Verbindungsfehler |
| `2` | Initialisierung, Konfiguration, Modul, Lock oder fehlgeschlagenes Credential bei `-ValidateOnly` |

## Credential-Dateien

| Datei | Zugang |
| --- | --- |
| `trend.sec` | SMB / Bari |
| `schlanser.sec` | SFTP SCHLANSER |
| `digitecgalaxus.sec` | SFTP GALAXUS |
| `brack.sec` | SFTP BRACK |
| `pagero2.sec` | SFTP PAGERO |

## Erste Diagnose

```powershell
.\TEST_PACKAGE.ps1
.\MAIN.ps1 -ListCustomers
.\MAIN.ps1 -Customer PAGERO -ValidateOnly
Test-NetConnection dometicsftpqa.blob.core.windows.net -Port 22
Get-Content '.\Log\transfer.log' -Tail 100
```

## Sicherheitsregeln

- `.sec`-Dateien nur unter dem Scheduler-Konto auf dem Zielserver erzeugen.
- `.sec`-Inhalte niemals anzeigen oder versenden.
- Hostkeyänderungen extern bestätigen lassen.
- Niemals `-Force` zu `New-SFTPSession` hinzufügen.
- Negative Tests nur in einer Testkopie/Testumgebung.
- Ohne `-ValidateOnly` kann `MAIN.ps1` Dateien übertragen.
