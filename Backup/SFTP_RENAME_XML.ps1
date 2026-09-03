$UtilsScript = Join-Path $PSScriptRoot $UtilsFile
. $UtilsScript


# Seller name to Pagero entity mapping.
# Add further companies here, for example:
# 'Another Seller GmbH' = 'DE99'
$script:SellerEntityMapping = @{
    'Dometic Benelux B.V.' = 'DE13'
}


function Join-SftpPath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Directory,

        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    if ([string]::IsNullOrWhiteSpace($Directory) -or $Directory -eq '/') {
        return '/' + $FileName
    }

    return $Directory.TrimEnd('/') + '/' + $FileName
}


function Get-SftpXmlRenamePlan {
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$LocalFile,

        [Parameter(Mandatory = $true)]
        [string]$RemoteDirectory
    )

    if ($LocalFile.Extension -ine '.xml') {
        return $null
    }

    # Read the XML with DTD processing disabled.
    $xmlDocument = New-Object System.Xml.XmlDocument
    $xmlDocument.PreserveWhitespace = $true

    $xmlSettings = New-Object System.Xml.XmlReaderSettings
    $xmlSettings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $xmlSettings.XmlResolver = $null

    $xmlReader = $null

    try {
        $xmlReader = [System.Xml.XmlReader]::Create($LocalFile.FullName, $xmlSettings)
        $xmlDocument.Load($xmlReader)
    }
    finally {
        if ($null -ne $xmlReader) {
            $xmlReader.Dispose()
        }
    }

    # Namespace-independent XPath, but restricted to the required seller node:
    # ApplicableHeaderTradeAgreement/SellerTradeParty/Name
    $sellerNameNode = $xmlDocument.SelectSingleNode(
        "/*[local-name()='CrossIndustryInvoice']" +
        "/*[local-name()='SupplyChainTradeTransaction']" +
        "/*[local-name()='ApplicableHeaderTradeAgreement']" +
        "/*[local-name()='SellerTradeParty']" +
        "/*[local-name()='Name']"
    )

    if ($null -eq $sellerNameNode -or [string]::IsNullOrWhiteSpace($sellerNameNode.InnerText)) {
        throw "Seller name not found in XML file '$($LocalFile.Name)'."
    }

    $sellerName = $sellerNameNode.InnerText.Trim()

    if (-not $script:SellerEntityMapping.ContainsKey($sellerName)) {
        throw "No entity mapping exists for seller '$sellerName' in XML file '$($LocalFile.Name)'."
    }

    $entity = $script:SellerEntityMapping[$sellerName]
    $invoiceNumber = [System.IO.Path]::GetFileNameWithoutExtension($LocalFile.Name)
    $timestamp = Get-Date -Format 'yyyyMMddHHmmssfff'
    $newFileName = '{0}-Invoice-{1}-{2}.xml' -f $entity, $invoiceNumber, $timestamp

    return [PSCustomObject]@{
        SellerName          = $sellerName
        Entity              = $entity
        OriginalFileName    = $LocalFile.Name
        NewFileName         = $newFileName
        RemoteSourcePath    = Join-SftpPath -Directory $RemoteDirectory -FileName $LocalFile.Name
        RemoteTargetPath    = Join-SftpPath -Directory $RemoteDirectory -FileName $newFileName
    }
}


function Invoke-SftpXmlRename {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$RenamePlan
    )

    if ($null -eq $global:SFTPSession) {
        throw 'SFTP server is not connected.'
    }

    Write-Host "Rename XML on SFTP server: $($RenamePlan.OriginalFileName) -> $($RenamePlan.NewFileName)"
    addLog "Rename XML on SFTP server: $($RenamePlan.RemoteSourcePath) -> $($RenamePlan.RemoteTargetPath)"

    Move-SFTPItem `
        -SFTPSession $global:SFTPSession `
        -Path $RenamePlan.RemoteSourcePath `
        -Destination $RenamePlan.RemoteTargetPath `
        -ErrorAction Stop | Out-Null

    Write-Host "XML file successfully renamed: $($RenamePlan.NewFileName)"
    addLog "XML file successfully renamed: $($RenamePlan.RemoteTargetPath)"
}
