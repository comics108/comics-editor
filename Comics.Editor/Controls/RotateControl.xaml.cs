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
	/// Interaction logic for RotateControl.xaml
	/// </summary>
	public partial class RotateControl : UserControl
	{
		private RotateAnim Model
		{
			get { return DataContext as RotateAnim; }
		}

		public RotateControl()
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
			var pivot = new Point(ActualWidth * Model.PivotX, ActualHeight * Model.PivotY);
			var thumbCenter = thumb.TranslatePoint(new Point(thumb.ActualWidth / 2, thumb.ActualHeight / 2), this);
			var newThumbCenter = Mouse.GetPosition(this);

			var origVector = thumbCenter - pivot;
			var newVector = newThumbCenter - pivot;
			Model.Angle += (int)Math.Round(Vector.AngleBetween(origVector, newVector));
		}
	}
}
