Add-Type -AssemblyName System.Xml.Linq
$path = 'DataSphere\Resources\Locales\String.vi.resx'
$doc = [System.Xml.Linq.XDocument]::Load($path)
$root = $doc.Root

function Add-ResKey($name, $val) {
    $existing = $root.Elements('data') | Where-Object { $_.Attribute('name').Value -eq $name }
    if (-not $existing) {
        $elem = New-Object System.Xml.Linq.XElement([System.Xml.Linq.XName]::Get('data'))
        $elem.SetAttributeValue('name', $name)
        $elem.SetAttributeValue([System.Xml.Linq.XNamespace]::Xml + 'space', 'preserve')
        $valElem = New-Object System.Xml.Linq.XElement([System.Xml.Linq.XName]::Get('value'), $val)
        $elem.Add($valElem)
        $root.Add($elem)
    }
}

Add-ResKey 'lbl_database_type' 'Loại cơ sở dữ liệu'
Add-ResKey 'msg_test_pg_socket' 'Máy chủ PostgreSQL phản hồi tốt trên cổng {0}. Tính năng truy vấn dữ liệu đang phát triển.'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$settings = New-Object System.Xml.XmlWriterSettings
$settings.Encoding = $utf8NoBom
$settings.Indent = $true
$settings.OmitXmlDeclaration = $false

$writer = [System.Xml.XmlWriter]::Create($path, $settings)
$doc.Save($writer)
$writer.Close()
Write-Host 'String.vi.resx updated via XDocument successfully'
