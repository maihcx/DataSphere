using System;
using MySqlConnector;

class Program
{
    static void Main()
    {
        try
        {
            using var conn = new MySqlConnection("Server=localhost;Port=3306;User ID=root;Password=;");
            conn.Open();
            using var cmd = conn.CreateCommand();
            cmd.CommandText = "SELECT table_schema, table_name, table_rows FROM information_schema.tables WHERE table_schema='ngocthamcatalog' AND table_name LIKE '%products_new%';";
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                Console.WriteLine($"{reader.GetString(0)}.{reader.GetString(1)} (Rows: {reader.GetValue(2)})");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine("Error: " + ex.Message);
        }
    }
}
