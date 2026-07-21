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
	/// Interaction logic for LayersControl.xaml
	/// </summary>
	public partial class LayersControl : UserControl
	{
		private ComicsViewModel Model
		{
			get { return DataContext as ComicsViewModel; }
		}

		public LayersControl()
		{
			InitializeComponent();
		}

		private void Button_Click(object sender, RoutedEventArgs e)
		{
			var btn = sender as ToggleButton;
			Model.SelectedItem = btn?.IsChecked == true ? btn?.DataContext as LayerViewModel : null;
		}
	}
}
