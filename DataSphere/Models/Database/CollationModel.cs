using System;
using System.Collections.Generic;
using System.Text;

namespace DataSphere.Models.Database
{
    public class CollationModel
    {
        public string Collation { get; set; } = string.Empty;

        public string Charset { get; set; } = string.Empty;

        public int Id { get; set; } = 0;

        public string Default { get; set; } = string.Empty;

        public string Compiled { get; set; } = string.Empty;

        public int Sortlen { get; set; } = 0;
    }
}
