using System;
using System.IO;
using System.Text;

namespace ResxUpdater
{
    class Program
    {
        static void Main()
        {
            UpdateResx("DataSphere/Resources/Locales/String.resx", "Select a table in the explorer to browse its records");
            UpdateResx("DataSphere/Resources/Locales/String.en.resx", "Select a table in the explorer to browse its records");
            UpdateResx("DataSphere/Resources/Locales/String.vi.resx", "Chọn một bảng trong danh sách để xem dữ liệu");
        }

        static void UpdateResx(string filePath, string value)
        {
            if (!File.Exists(filePath))
            {
                Console.WriteLine($"File not found: {filePath}");
                return;
            }

            string content = File.ReadAllText(filePath, Encoding.UTF8);
            if (content.Contains("page_db_select_table_hint"))
            {
                Console.WriteLine($"Already exists in {filePath}");
                return;
            }

            int rootIndex = content.LastIndexOf("</root>");
            if (rootIndex == -1)
            {
                Console.WriteLine($"</root> tag not found in {filePath}");
                return;
            }

            string entry = $"  <data name=\"page_db_select_table_hint\" xml:space=\"preserve\">\r\n    <value>{value}</value>\r\n  </data>\r\n";
            string updated = content.Insert(rootIndex, entry);

            File.WriteAllText(filePath, updated, new UTF8Encoding(false));
            Console.WriteLine($"Successfully updated {filePath}");
        }
    }
}
