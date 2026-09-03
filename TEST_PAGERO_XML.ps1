#Requires -Version 5.1

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$XmlPath
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Utils.ps1')
. (Join-Path $PSScriptRoot 'PageroXml.ps1')

$configuration = & (Join-Path $PSScriptRoot 'USER_PARAM.ps1')
$pagero = $configuration.Customers | Where-Object { $_.CustomerId -eq 'PAGERO' }
$xmlFile = Get-Item -LiteralPath $XmlPath -ErrorAction Stop

$plan = Get-PageroXmlRenamePlan `
    -LocalFile $xmlFile `
    -RemoteDirectory $pagero.RemoteDirectory `
    -SellerEntityMapping $pagero.SellerEntityMapping

$plan | Format-List SellerName, Entity, OriginalFileName, NewFileName, RemoteSourcePath, RemoteTargetPath
