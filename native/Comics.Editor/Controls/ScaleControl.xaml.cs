using Comics.Editor.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
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
	/// Interaction logic for ScaleControl.xaml
	/// </summary>
	public partial class ScaleControl : UserControl
	{
		private ScaleAnim Model
		{
			get { return DataContext as ScaleAnim; }
		}

		public ScaleControl()
		{
			InitializeComponent();
		}

		private void PivotThumb_DragDelta(object sender, DragDeltaEventArgs e)
		{
			Model.PivotX += e.HorizontalChange / ActualWidth;
			Model.PivotY += e.VerticalChange / ActualHeight;
		}

		private void Thumb_DragDelta(object sender, DragDeltaEventArgs e)
		{
			var thumb = sender as Thumb;
			var dx = thumb.HorizontalAlignment == HorizontalAlignment.Left ? -e.HorizontalChange : e.HorizontalChange;
			var dy = thumb.VerticalAlignment == VerticalAlignment.Top ? -e.VerticalChange : e.VerticalChange;

			var delta = (dx > dy ? dx : dy) / (dx > dy ? ActualWidth : ActualHeight);
			Model.ScaleX = Math.Max(Model.ScaleX + delta, 0.1);
			Model.ScaleY = Math.Max(Model.ScaleY + delta, 0.1);
		}
	}
}
