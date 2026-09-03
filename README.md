# Vereinheitlichtes TREND-SFTP-Paket

Dieses Paket ersetzt die zwei bisherigen Main-/Parameter-Varianten durch genau
eine `MAIN.ps1` und eine `USER_PARAM.ps1`.

## Verarbeitungsregeln

| Kunde | Standardprofil | Verarbeitungsart | Dateiname auf SFTP |
| --- | --- | --- | --- |
| SCHLANSER | DAILY | STANDARD | unverändert |
| GALAXUS | DAILY | STANDARD | unverändert |
| BRACK | DAILY | STANDARD | unverändert |
| PAGERO | HOURLY | PAGERO_XML_RENAME | Entity-Invoice-Nummer-Timestamp.xml |

Die Profilzuordnung folgt der bisherigen Trennung: Die drei CSV-Transfers lagen
in `USER_PARAM.ps1`; Pagero wurde über die separate `MAIN_MINUTE`-/Parameterdatei
verarbeitet. Falls ein Kunde anders getaktet werden soll, wird ausschließlich
sein `RunProfile` in `USER_PARAM.ps1` geändert.

Nur Pagero liest den XML-Inhalt und wertet `SellerTradeParty/Name` aus. Das
Mapping steht unter `SellerEntityMapping` in `USER_PARAM.ps1`. Enthalten ist:

```text
Dometic Benelux B.V. = DE13
```

Der Pagero-Timestamp wird aus `LastWriteTimeUtc` der Quelldatei gebildet. Dadurch
ist die Wiederholung idempotent: Eine unveränderte Quelldatei erzeugt immer
denselben SFTP-Zielnamen. Existiert dieser bereits, wird die Datei nicht erneut
hochgeladen.

Nach erfolgreicher Verarbeitung wird die lokale Quelldatei bei allen Kunden auf
die Erweiterung `.done` umbenannt. Beispiele:

```text
2026600172.xml                  -> 2026600172.done
SCHLANSERout_2026090380642.csv -> SCHLANSERout_2026090380642.done
```

Bei Pagero gilt ein bereits vorhandener deterministischer SFTP-Zielname ebenfalls
als erfolgreich abgearbeitet; auch dann wird die lokale XML-Datei auf `.done`
umbenannt. Existiert die lokale `.done`-Datei bereits, wird sie nicht
überschrieben und der Kundenlauf meldet einen Fehler.

## Installation

1. Die bisherigen Skripte aus `D:\TREND_SFTP` sichern.
2. Den Inhalt dieses Pakets direkt nach `D:\TREND_SFTP` kopieren.
3. Die vorhandenen verschlüsselten Dateien in `D:\TREND_SFTP\secure` behalten.
4. `USER_PARAM_2.ps1` und die separate Main-Variante werden nicht mehr benötigt.
5. Die Validierung mit demselben Windows-Konto ausführen, das im Task Scheduler
   verwendet wird.

```powershell
powershell.exe -NoProfile -File "D:\TREND_SFTP\TEST_PACKAGE.ps1"
powershell.exe -NoProfile -File "D:\TREND_SFTP\TEST_AFTER_COPY.ps1"
powershell.exe -NoProfile -File "D:\TREND_SFTP\MAIN.ps1" -RunProfile HOURLY -ValidateOnly
powershell.exe -NoProfile -File "D:\TREND_SFTP\MAIN.ps1" -RunProfile DAILY -ValidateOnly
```

Mit `ConvertFrom-SecureString` erzeugte `.sec`-Dateien sind normalerweise an
Windows-Benutzer und Computer gebunden. Der geplante Task muss daher unter dem
Konto laufen, mit dem die Dateien erzeugt wurden.

Die Credential-Dateien dürfen mit `Out-File` oder `Set-Content` erzeugt worden
sein. Das Paket entfernt beim Einlesen automatisch abschließende Zeilenumbrüche.
Falls die Entschlüsselung danach weiterhin fehlschlägt, `trend.sec` einmal auf
dem Zielserver unter genau dem Windows-Konto des geplanten Tasks neu erzeugen:

```powershell
Read-Host 'SFTP-Passwort für PAGERO' -AsSecureString |
    ConvertFrom-SecureString |
    Set-Content -LiteralPath 'D:\TREND_SFTP\secure\trend.sec' -Encoding UTF8
```

## Task Scheduler

Stündlicher Pagero-Task:

```text
Programm: powershell.exe
Argumente: -NoLogo -NoProfile -NonInteractive -File "D:\TREND_SFTP\MAIN.ps1" -RunProfile HOURLY
Starten in: D:\TREND_SFTP
```

Täglicher Task für Schlanser, Galaxus und Brack:

```text
Programm: powershell.exe
Argumente: -NoLogo -NoProfile -NonInteractive -File "D:\TREND_SFTP\MAIN.ps1" -RunProfile DAILY
Starten in: D:\TREND_SFTP
```

Manueller Lauf für einen oder mehrere Kunden, unabhängig vom Profil:

```powershell
powershell.exe -NoProfile -File "D:\TREND_SFTP\MAIN.ps1" -Customer PAGERO
powershell.exe -NoProfile -File "D:\TREND_SFTP\MAIN.ps1" -Customer "SCHLANSER,BRACK"
```

Konfigurierte Kunden anzeigen, ohne eine Verbindung aufzubauen:

```powershell
powershell.exe -NoProfile -File "D:\TREND_SFTP\MAIN.ps1" -ListCustomers
```

Nur das Pagero-Mapping und den neuen Dateinamen testen:

```powershell
powershell.exe -NoProfile -File "D:\TREND_SFTP\TEST_PAGERO_XML.ps1" -XmlPath "D:\Temp\2026600172.xml"
```

## Zuverlässigkeit und Sicherheit

- Eine Sperrdatei verhindert überlappende stündliche und tägliche Läufe.
- Die Konfiguration wird als neues Objekt geladen; alte globale Parameter können
  nicht wiederverwendet werden.
- Jeder Kunde erhält einen eigenen Lauf für Netzlaufwerk und SFTP-Session.
- Eine fehlgeschlagene Verbindung kann niemals auf die Session des vorherigen
  Kunden zurückfallen.
- Das SFTP-Zielverzeichnis wird vor dem Upload geprüft.
- Zu neue oder exklusiv gesperrte Quelldateien werden übersprungen.
- Erfolgreich abgearbeitete Quelldateien erhalten die Erweiterung `.done` und
  fallen dadurch aus den aktiven `.xml`-/`.csv`-Dateifiltern heraus.
- Vorhandene `.done`-Ziele werden niemals stillschweigend überschrieben.
- Pagero-XMLs werden vor dem Upload validiert und gemappt.
- Alle anderen Kunden verwenden `STANDARD`; eine XML-Umbenennung ist für sie
  technisch gesperrt.
- Geänderte SSH-Hostkeys bleiben blockierende Fehler. Posh-SSH `-Force` darf
  nicht zur Umgehung der Hostkey-Prüfung verwendet werden.
- Das Protokoll liegt unter `D:\TREND_SFTP\Log\transfer.log`.

## Rückgabecodes

| Code | Bedeutung |
| --- | --- |
| 0 | Lauf erfolgreich |
| 1 | Mindestens ein Kunde oder eine Datei ist fehlgeschlagen |
| 2 | Konfigurations-, Abhängigkeits-, Credential- oder Sperrfehler |

## Aktueller Galaxus-Hinweis

Der beobachtete Galaxus-Hostkey-Konflikt muss durch Digitec Galaxus bestätigt
werden, bevor der gespeicherte Trusted-Host-Eintrag geändert wird. Der Pfad
`/StockData_EU` darf erst nach erfolgreichem Aufbau einer echten Galaxus-Session
erneut bewertet werden.
"# TREND_SFTP" 
