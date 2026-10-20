Add-Type @'
using System;
using System.IO;
using System.Text;
using System.Xml.Linq;

public class ResxPatcher {
    public static void Patch() {
        string path = @"DataSphere\Resources\Locales\String.vi.resx";
        XDocument doc = XDocument.Load(path);
        XElement root = doc.Root;

        string titleVal = "Lo\u1EA1i c\u01A1 s\u1EDF d\u1EEF li\u1EC7u";
        string msgVal = "M\u00E1y ch\u1EE7 PostgreSQL ph\u1EA3n h\u1ED3i t\u1ED1t tr\u00EAn c\u1ED5ng {0}. T\u00EDnh n\u0103ng truy v\u1EA5n d\u1EEF li\u1EC7u \u0111ang ph\u00E1t tri\u1EC3n.";

        SetKey(root, "lbl_database_type", titleVal);
        SetKey(root, "msg_test_pg_socket", msgVal);

        var utf8NoBom = new UTF8Encoding(false);
        var settings = new System.Xml.XmlWriterSettings {
            Encoding = utf8NoBom,
            Indent = true,
            OmitXmlDeclaration = false
        };

        using (var writer = System.Xml.XmlWriter.Create(path, settings)) {
            doc.Save(writer);
        }
    }

    private static void SetKey(XElement root, string name, string val) {
        foreach (var el in root.Elements("data")) {
            var attr = el.Attribute("name");
            if (attr != null && attr.Value == name) {
                var v = el.Element("value");
                if (v != null) v.Value = val;
                return;
            }
        }
        var elem = new XElement("data",
            new XAttribute("name", name),
            new XAttribute(XNamespace.Xml + "space", "preserve"),
            new XElement("value", val)
        );
        root.Add(elem);
    }
}
'@ -ReferencedAssemblies System.Xml, System.Xml.Linq
[ResxPatcher]::Patch()
Write-Host "C# Patch completed."
