using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DataSphere.Models
{
    public class DatabaseTypes
    {
        public DatabaseType Value { get; set; }

        public string Name
        {
            get => Value.ToString();
        }

        public override string ToString()
        {
            return Value.ToString();
        }

        public override bool Equals(object? obj)
        {
            return obj is DatabaseTypes other && this.Value == other.Value;
        }

        public override int GetHashCode()
        {
            return Value.ToString().GetHashCode();
        }
    }
}
