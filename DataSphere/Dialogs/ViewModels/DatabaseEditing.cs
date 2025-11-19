using DataSphere.Models.Database;
using DataSphere.Services.Database.Interface;
using System;
using System.Collections.Generic;
using System.Text;

namespace DataSphere.Dialogs.ViewModels
{
    public partial class DatabaseEditing : ObservableObject, IDataErrorInfo
    {

        [ObservableProperty]
        private bool _isAllowSubmit = false;

        [ObservableProperty]
        private string _databaseName = string.Empty;

        [ObservableProperty]
        private ObservableCollection<CollationModel>? _databaseCollation;

        [ObservableProperty]
        private CollationModel? _databaseCollationSelected;

        private DatabaseInfo? iDatabaseInfo;

        public IDatabaseConnection? DatabaseConnection = null;

        public async void InitializeViewModel(IDatabaseConnection? connection)
        {
            if (connection != null)
            {
                DatabaseConnection = connection;

                DatabaseCollation = await connection.GetAllCollation();

                if (DatabaseCollation != null)
                {
                    DatabaseCollationSelected = DatabaseCollation.FirstOrDefault(x => x.Collation == "utf8mb4_unicode_ci") ?? new CollationModel();
                }
            }
        }

        public string Error => string.Empty;

        public string this[string columnName]
        {
            get
            {
                switch (columnName)
                {
                    case nameof(DatabaseName):
                        if (string.IsNullOrWhiteSpace(DatabaseName))
                            return "DatabaseName is required";
                        break;
                    case nameof(DatabaseCollationSelected):
                        if (DatabaseCollationSelected == null || DatabaseCollationSelected.Collation == "")
                            return "DatabaseCollationSelected is required";
                        break;
                }
                return string.Empty;
            }
        }

        public DatabaseInfo? ToDatabaseInfo()
        {
            if (iDatabaseInfo == null)
            {
                iDatabaseInfo = new DatabaseInfo();
            }

            DatabaseCollationSelected ??= iDatabaseInfo.Collation;
            iDatabaseInfo.Collation = DatabaseCollationSelected;

            iDatabaseInfo.Name = DatabaseName;
            return iDatabaseInfo;
        }

        public void SetModel(DatabaseInfo? model)
        {
            if (model != null)
            {
                DatabaseName = model.Name;
                if (DatabaseCollation != null)
                {
                    iDatabaseInfo = model;
                    DatabaseCollationSelected = DatabaseCollation.FirstOrDefault(x => x.Collation == model.Collation.Collation) ?? new CollationModel();
                }
            }
        }
    }
}
