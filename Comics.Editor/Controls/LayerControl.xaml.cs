using System;
using System.Collections.Generic;
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
	/// Interaction logic for LayerControl.xaml
	/// </summary>
	public partial class LayerControl : UserControl
	{
		public static readonly DependencyProperty OrientationProperty = DependencyProperty.Register("Orientation", typeof(Orientation), typeof(LayerControl), new PropertyMetadata(Orientation.Vertical));

		public Orientation Orientation
		{
			get { return (Orientation)GetValue(OrientationProperty); }
			set { SetValue(OrientationProperty, value); }
		}

		public LayerControl()
		{
			InitializeComponent();
		}
	}
}
