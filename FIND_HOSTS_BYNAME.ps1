


param ($Path)

$Folder = $Path 
Get-PSDrive | Where-Object {
$_.root -match "[C-Z]:\\" -and (Test-Path $(Join-Path $_.root $Folder))
}
