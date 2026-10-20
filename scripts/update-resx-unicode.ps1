Add-Type -AssemblyName System.Xml.Linq
$path = 'DataSphere\Resources\Locales\String.vi.resx'
$doc = [System.Xml.Linq.XDocument]::Load($path)
$root = $doc.Root

function Set-ResKey($name, [string]$val) {
    $existing = $root.Elements([System.Xml.Linq.XName]::Get('data')) | Where-Object { $_.Attribute('name').Value -eq $name }
    if ($existing) {
        $existing.Element([System.Xml.Linq.XName]::Get('value')).Value = $val
    } else {
        $elem = New-Object System.Xml.Linq.XElement([System.Xml.Linq.XName]::Get('data'))
        $elem.SetAttributeValue('name', $name)
        $elem.SetAttributeValue([System.Xml.Linq.XNamespace]::Xml + 'space', 'preserve')
        $valElem = New-Object System.Xml.Linq.XElement([System.Xml.Linq.XName]::Get('value'), $val)
        $elem.Add($valElem)
        $root.Add($elem)
    }
}

$titleVal = "Lo`u{1EA1}i c`u{01A1} s`u{1EDF} d`u{1EEF} li`u{1EC7}u"
$msgVal = "M`u{00E1}y ch`u{1EE7} PostgreSQL ph`u{1EA3}n h`u{1ED3}i t`u{1ED1}t tr`u{00EAn} c`u{1ED5}ng {0}. T`u{00ED}nh n`u{0103}ng truy v`u{1EA5}n d`u{1EEF} li`u{1EC7}u `u{0111}ang ph`u{00E1}t tri`u{1EC3}n."

Set-ResKey 'lbl_database_type' $titleVal
Set-ResKey 'msg_test_pg_socket' $msgVal

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$settings = New-Object System.Xml.XmlWriterSettings
$settings.Encoding = $utf8NoBom
$settings.Indent = $true
$settings.OmitXmlDeclaration = $false

$writer = [System.Xml.XmlWriter]::Create($path, $settings)
$doc.Save($writer)
$writer.Close()
Write-Host 'String.vi.resx updated with Unicode escapes successfully'
