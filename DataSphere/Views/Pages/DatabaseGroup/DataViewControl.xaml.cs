using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using DataSphere.Models.Database;
using DataSphere.Services.Database.Interface;
using DataSphere.ViewModels.Pages.DatabaseGroup;

namespace DataSphere.Views.Pages.DatabaseGroup
{
    /// <summary>
    /// UserControl presenting a high-performance paginated table data viewport
    /// with viewport-pinned vertical scrollbar and synchronized horizontal header scrolling.
    /// </summary>
    public sealed partial class DataViewControl : UserControl, IDisposable
    {
        private ScrollViewer? _listScrollViewer;
        private double _lastHorizontalOffset = -1;

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

            Loaded += OnLoaded;
            Unloaded += OnUnloaded;
        }

        private void OnLoaded(object sender, RoutedEventArgs e)
        {
            AttachScrollSynchronization();
        }

        private void OnUnloaded(object sender, RoutedEventArgs e)
        {
            DetachScrollSynchronization();
        }

        /// <summary>
        /// Attaches scroll synchronization between the row ListView internal ScrollViewer and the header ScrollViewer.
        /// </summary>
        private void AttachScrollSynchronization()
        {
            if (_listScrollViewer == null && DataRowsListView != null)
            {
                _listScrollViewer = FindVisualChild<ScrollViewer>(DataRowsListView);
                if (_listScrollViewer != null)
                {
                    _listScrollViewer.ViewChanged += OnListViewChanged;
                }
            }
        }

        /// <summary>
        /// Detaches scroll synchronization event handlers to prevent memory leaks.
        /// </summary>
        private void DetachScrollSynchronization()
        {
            if (_listScrollViewer != null)
            {
                _listScrollViewer.ViewChanged -= OnListViewChanged;
                _listScrollViewer = null;
            }
        }

        /// <summary>
        /// Handles changes in the row ListView viewport offset and synchronizes the header ScrollViewer.
        /// Filters out vertical-only scroll deltas to prevent UI thread layout stalls and event ping-pong.
        /// </summary>
        /// <param name="sender">The source of the event.</param>
        /// <param name="e">Event arguments specifying viewport changes.</param>
        private void OnListViewChanged(object? sender, ScrollViewerViewChangedEventArgs e)
        {
            if (_listScrollViewer == null || HeaderScrollViewer == null)
            {
                return;
            }

            double currentOffset = _listScrollViewer.HorizontalOffset;
            if (Math.Abs(currentOffset - _lastHorizontalOffset) < 0.5)
            {
                // Purely vertical scroll. Skip header scroll updates completely to avoid UI thread lag.
                return;
            }

            _lastHorizontalOffset = currentOffset;
            HeaderScrollViewer.ChangeView(currentOffset, null, null, true);
        }

        /// <summary>
        /// Recursively searches the visual tree for a descendant element of the specified type.
        /// </summary>
        /// <typeparam name="T">The type of visual element to find.</typeparam>
        /// <param name="parent">The root element from which to begin the search.</param>
        /// <returns>The found element of type <typeparamref name="T"/>, or <c>null</c> if not found.</returns>
        private static T? FindVisualChild<T>(DependencyObject parent) where T : DependencyObject
        {
            int childCount = VisualTreeHelper.GetChildrenCount(parent);
            for (int i = 0; i < childCount; i++)
            {
                DependencyObject child = VisualTreeHelper.GetChild(parent, i);
                if (child is T typedChild)
                {
                    return typedChild;
                }

                T? childOfChild = FindVisualChild<T>(child);
                if (childOfChild != null)
                {
                    return childOfChild;
                }
            }

            return null;
        }

        /// <inheritdoc/>
        public void Dispose()
        {
            DetachScrollSynchronization();
            ViewModel.Dispose();
        }
    }
}
