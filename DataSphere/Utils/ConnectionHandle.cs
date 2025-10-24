using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DataSphere.Utils
{
    public static class ConnectionHandle
    {
        public static bool IsNotEmpty
        {
            get => field;
            private set
            {
                field = value;
            }
        } = false;

        public static int ConnectLenght
        {
            get => field;
            private set
            {
                field = value;
                OnConnectLenghtChanged?.Invoke(field);
                IsNotEmpty = field > 0;
            }
        }

        public delegate void ConnectLenghtEvent(int connectLenght);
        public static event ConnectLenghtEvent? OnConnectLenghtChanged;
    }
}
