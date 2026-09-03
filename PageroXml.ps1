function Get-PageroXmlRenamePlan {
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$LocalFile,

        [Parameter(Mandatory = $true)]
        [string]$RemoteDirectory,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$SellerEntityMapping
    )

    if ($LocalFile.Extension -ine '.xml') {
        throw "Pagero processing supports XML files only: '$($LocalFile.Name)'."
    }

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

    $sellerNameNode = $xmlDocument.SelectSingleNode(
        "/*[local-name()='CrossIndustryInvoice']" +
        "/*[local-name()='SupplyChainTradeTransaction']" +
        "/*[local-name()='ApplicableHeaderTradeAgreement']" +
        "/*[local-name()='SellerTradeParty']" +
        "/*[local-name()='Name']"
    )

    if ($null -eq $sellerNameNode -or [string]::IsNullOrWhiteSpace($sellerNameNode.InnerText)) {
        throw "SellerTradeParty/Name not found in XML file '$($LocalFile.Name)'."
    }

    $sellerName = $sellerNameNode.InnerText.Trim()

    if (-not $SellerEntityMapping.Contains($sellerName)) {
        throw "No Pagero entity mapping exists for seller '$sellerName' in '$($LocalFile.Name)'."
    }

    $entity = [string]$SellerEntityMapping[$sellerName]
    $invoiceNumber = [System.IO.Path]::GetFileNameWithoutExtension($LocalFile.Name)

    if ($entity -notmatch '^[A-Za-z0-9_-]+$') {
        throw "Pagero entity '$entity' contains unsupported filename characters."
    }

    # A timestamp based on LastWriteTimeUtc makes retries idempotent. The same
    # unchanged source file always produces the same remote target name.
    $timestamp = $LocalFile.LastWriteTimeUtc.ToString(
        'yyyyMMddHHmmssfff',
        [System.Globalization.CultureInfo]::InvariantCulture
    )

    $newFileName = '{0}-Invoice-{1}-{2}.xml' -f $entity, $invoiceNumber, $timestamp

    return [PSCustomObject]@{
        SellerName       = $sellerName
        Entity           = $entity
        OriginalFileName = $LocalFile.Name
        NewFileName      = $newFileName
        RemoteSourcePath = Join-SftpPath -Directory $RemoteDirectory -Name $LocalFile.Name
        RemoteTargetPath = Join-SftpPath -Directory $RemoteDirectory -Name $newFileName
    }
}
