using Comics.Editor.Models;
using Comics.Editor.ViewModel;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;

namespace Comics.Editor.Controls
{
	/// <summary>
	/// Interaction logic for ComicsControl.xaml
	/// </summary>
	public partial class ComicsControl : UserControl
	{
		private ComicsViewModel Model
		{
			get { return DataContext as ComicsViewModel; }
		}

		public ComicsControl()
		{
			InitializeComponent();
		}

		/// <summary>Normalized review position used by the Flutter Viewer rail.</summary>
		public double NormalizedPosition
		{
			get
			{
				var extent = scrollViewer.ScrollableHeight;
				return extent <= 0 ? 0 : Math.Max(0, Math.Min(1, scrollViewer.VerticalOffset / extent));
			}
		}

		public void SetNormalizedPosition(double value)
		{
			value = Math.Max(0, Math.Min(1, value));
			scrollViewer.ScrollToVerticalOffset(scrollViewer.ScrollableHeight * value);
		}

		private void UserControl_DataContextChanged(object sender, DependencyPropertyChangedEventArgs e)
		{
			if (e.OldValue is ComicsViewModel oldModel)
				oldModel.PropertyChanged -= Model_PropertyChanged;
			if (Model == null)
				return;

			scrollViewer.ScrollToVerticalOffset(Model.Scroll);
			Model.PropertyChanged += Model_PropertyChanged;
		}

		private void Model_PropertyChanged(object sender, PropertyChangedEventArgs e)
		{
			if (e.PropertyName == nameof(Model.Scroll) && scrollViewer.VerticalOffset != Model.Scroll)
				scrollViewer.ScrollToVerticalOffset(Model.Scroll);
		}

		private void ScrollViewer_ScrollChanged(object sender, ScrollChangedEventArgs e)
		{
			Model.Scroll = e.VerticalOffset;
		}
	}
}
