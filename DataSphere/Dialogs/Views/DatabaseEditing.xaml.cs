using System;
using System.Collections.Generic;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;

namespace DataSphere.Dialogs.Views
{
    /// <summary>
    /// Interaction logic for DatabaseEditing.xaml
    /// </summary>
    public partial class DatabaseEditing : ContentDialog, IDialogWithResult<ViewModels.DatabaseEditing>, IDialogWithModel
    {
        public ViewModels.DatabaseEditing ViewModel { get; }

        public ViewModels.DatabaseEditing? Result { get; private set; }

        private string CurrentDBName = string.Empty;

        public DatabaseEditing(ContentPresenter? contentPresenter) : base(contentPresenter)
        {
            ViewModel = new ViewModels.DatabaseEditing();
            DataContext = this;

            InitializeComponent();

            (new Task(() =>
            {
                Thread.Sleep(200);
                Dispatcher.Invoke(() =>
                {
                    txtDatabaseName.Focus();
                });
            })).Start();
        }

        protected override async void OnButtonClick(ContentDialogButton button)
        {
            if (button == ContentDialogButton.Primary)
            {
                tblErrorResp.Visibility = Visibility.Collapsed;

                Control? _firstInvalidControl = null;
                bool isValid = true;

                foreach (var child in FindVisualChildren<Wpf.Ui.Controls.TextBox>(this))
                {
                    var binding = child.GetBindingExpression(Wpf.Ui.Controls.TextBox.TextProperty);
                    binding?.UpdateSource();

                    if (binding?.ResolvedSourcePropertyName is string prop)
                    {
                        var error = ((IDataErrorInfo)ViewModel)[prop];
                        if (!string.IsNullOrEmpty(error))
                        {
                            _firstInvalidControl ??= child;
                            isValid = false;
                        }
                    }
                }

                if (!isValid && _firstInvalidControl != null)
                {
                    _firstInvalidControl.Focus();
                    return;
                }

                string DBName = txtDatabaseName.Text.Trim();

                if (ViewModel.DatabaseConnection != null && CurrentDBName != DBName && await ViewModel.DatabaseConnection.DatabaseExistsAsync(DBName))
                {
                    tblErrorResp.Visibility = Visibility.Visible;
                    tblErrorResp.Text = LanguageBase.GetLangValue("err_table_exist_params", DBName);

                    return;
                }

                Result = ViewModel;
            }

            base.OnButtonClick(button);
        }

        private static IEnumerable<T> FindVisualChildren<T>(DependencyObject depObj) where T : DependencyObject
        {
            if (depObj == null)
                yield break;

            for (int i = 0; i < VisualTreeHelper.GetChildrenCount(depObj); i++)
            {
                var child = VisualTreeHelper.GetChild(depObj, i);
                if (child is T t)
                    yield return t;

                foreach (var childOfChild in FindVisualChildren<T>(child))
                    yield return childOfChild;
            }
        }

        public void SetModel(object? model)
        {
            if (model is Models.Database.DatabaseInfo databaseInfo)
            {
                ViewModel.SetModel(databaseInfo);
                CurrentDBName = databaseInfo.Name;
            }
        }
    }
}
