using System;
using Microsoft.UI.Xaml.Controls;
using DataSphere.Models;
using DataSphere.Models.Database;
using DataSphere.Services.Database.Interface;
using DataSphere.ViewModels.Pages.DatabaseGroup;

namespace DataSphere.Views.Pages.DatabaseGroup
{
    /// <summary>
    /// UserControl presenting a modern, high-performance database table data viewport
    /// driven declaratively by <see cref="DataControlViewModel"/>.
    /// </summary>
    public sealed partial class DataViewControl : UserControl, IDisposable
    {
        private bool _disposed;

        /// <summary>
        /// Gets the ViewModel driving the table data viewport.
        /// </summary>
        public DataControlViewModel ViewModel { get; }

        /// <summary>
        /// Initializes a new instance of the <see cref="DataViewControl"/> class.
        /// </summary>
        /// <param name="connection">The active database connection session.</param>
        /// <param name="database">The database schema.</param>
        /// <param name="table">The table definition.</param>
        public DataViewControl(IDatabaseConnection connection, DatabaseInfo database, Table table)
        {
            ViewModel = new DataControlViewModel(connection, database, table);
            InitializeComponent();
        }

        /// <inheritdoc/>
        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;

            ViewModel.Dispose();
        }
    }
}
