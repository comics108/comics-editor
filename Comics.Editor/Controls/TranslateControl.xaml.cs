using Comics.Editor.Models;
using Comics.Editor.ViewModel;
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
	/// Interaction logic for TranslateControl.xaml
	/// </summary>
	public partial class TranslateControl : UserControl
	{
		private UIElement _parent;

		private TranslateAnim Model
		{
			get { return DataContext as TranslateAnim; }
		}

		public TranslateControl()
		{
			InitializeComponent();
			_parent = FindVisualParent<Canvas>(this);
		}

		private void Thumb_DragDelta(object sender, DragDeltaEventArgs e)
		{
			// need to convert thumb coordinates to canvas coordinates to properly move the layer if rotate animation was applied.
			var thumb = sender as Thumb;
			var thumbCenter = thumb.TranslatePoint(new Point(thumb.ActualWidth / 2, thumb.ActualHeight / 2), _parent);
			var newThumbCenter = Mouse.GetPosition(_parent);

			var vector = newThumbCenter - thumbCenter;
			Model.X += (int)vector.X;
			Model.Y += (int)vector.Y;
		}

		private static T FindVisualParent<T>(DependencyObject child)
			where T : UIElement
		{
			var parent = VisualTreeHelper.GetParent(child);
			return parent == null ? null : parent is T ? (T)parent : FindVisualParent<T>(parent);
		}
	}
}
