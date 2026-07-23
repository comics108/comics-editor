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
	/// Interaction logic for SoundsControl.xaml
	/// </summary>
	public partial class SoundsControl : UserControl
	{
		public static readonly DependencyProperty OrientationProperty = DependencyProperty.Register("Orientation", typeof(Orientation), typeof(SoundsControl), new PropertyMetadata(Orientation.Vertical));

		public Orientation Orientation
		{
			get { return (Orientation)GetValue(OrientationProperty); }
			set { SetValue(OrientationProperty, value); }
		}

		private ComicsViewModel Model
		{
			get { return DataContext as ComicsViewModel; }
		}

		public SoundsControl()
		{
			InitializeComponent();
		}

		private void SoundsControl_Loaded(object sender, RoutedEventArgs e)
		{
			LayoutTransform = new RotateTransform(Orientation == Orientation.Vertical ? -90 : 0);
		}

		private void Button_Click(object sender, RoutedEventArgs e)
		{
			var btn = sender as ToggleButton;
			Model.SelectedItem = btn?.IsChecked == true ? btn?.DataContext as SoundViewModel : null;
		}
	}
}
