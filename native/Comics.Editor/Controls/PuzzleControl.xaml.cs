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
	/// Interaction logic for PuzzleControl.xaml
	/// </summary>
	public partial class PuzzleControl : UserControl
	{
		private PuzzleViewModel Model
		{
			get { return DataContext as PuzzleViewModel; }
		}

		public PuzzleControl()
		{
			InitializeComponent();
		}

		private void UserControl_DataContextChanged(object sender, DependencyPropertyChangedEventArgs e)
		{
			if (Model == null)
				return;

			scrollViewer.ScrollToHorizontalOffset(Model.Scroll * Model.Scale);
			Model.PropertyChanged += Model_PropertyChanged;
		}

		private void Model_PropertyChanged(object sender, PropertyChangedEventArgs e)
		{
			if (e.PropertyName == nameof(Model.Scroll) && scrollViewer.HorizontalOffset != Model.Scroll)
				scrollViewer.ScrollToHorizontalOffset(Model.Scroll * Model.Scale);
		}

		private void ScrollViewer_ScrollChanged(object sender, ScrollChangedEventArgs e)
		{
			Model.Scroll = e.HorizontalOffset / Model.Scale;
		}
	}
}
