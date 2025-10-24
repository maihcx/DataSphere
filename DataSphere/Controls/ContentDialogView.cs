using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DataSphere.Controls
{
    /// <summary>
    /// Interaction logic for ContentDialogView.xaml
    /// </summary>
    public partial class ContentDialogView : ContentDialog
    {
        public ContentDialogView(ContentPresenter? contentPresenter)
        : base(contentPresenter)
        {

        }

        public void Initialize(ContentPresenter? contentPresenter)
        {
            if (contentPresenter != null)
            {
                DialogHost = contentPresenter;
            }
        }
    }
}
