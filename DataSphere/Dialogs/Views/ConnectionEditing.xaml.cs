namespace DataSphere.Dialogs.Views
{
    /// <summary>
    /// Interaction logic for ConnectionEditing.xaml
    /// </summary>
    public partial class ConnectionEditing : ContentDialog, IDialogWithResult<ViewModels.ConnectionEditing>, IDialogWithModel
    {
        public ViewModels.ConnectionEditing ViewModel { get; }

        public ViewModels.ConnectionEditing? Result { get; private set; }

        public ConnectionEditing(ContentPresenter? contentPresenter) : base(contentPresenter)
        {
            ViewModel = new ViewModels.ConnectionEditing();
            DataContext = this;

            InitializeComponent();

            (new Task(() =>
            {
                Thread.Sleep(200);
                Dispatcher.Invoke(() =>
                {
                    txtConnectionName.Focus();
                });
            })).Start();
        }

        protected override bool OnPrimaryButtonClick()
        {
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
                return false;
            }

            Result = ViewModel;

            return base.OnPrimaryButtonClick();
        }

        protected override bool OnCloseButtonClick()
        {
            Result = null;

            return base.OnCloseButtonClick();
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
            if (model is Models.ConnectionModel connection)
            {
                ViewModel.SetModel(connection);
            }
        }
    }
}
