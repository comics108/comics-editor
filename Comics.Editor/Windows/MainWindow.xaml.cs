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

namespace Comics.Editor.Windows
{
	/// <summary>
	/// Interaction logic for MainWindow.xaml
	/// </summary>
	public partial class MainWindow : Window
	{
		private MainViewModel Model
		{
			get { return DataContext as MainViewModel; }
		}

		public MainWindow()
		{
			InitializeComponent();

			DataContext = new MainViewModel();
			Model.PropertyChanged += Model_PropertyChanged;
		}

		private void Model_PropertyChanged(object sender, PropertyChangedEventArgs e)
		{
			if (e.PropertyName != "File")
				return;

			var file = Model.File;
			Model.PropertyChanged -= Model_PropertyChanged;
			Model.Dispose();

			if (file == "<new comics>" || file.EndsWith(".comics"))
				DataContext = new ComicsViewModel(file);
			else if (file == "<new puzzle>" || file.EndsWith(".puzzle"))
				DataContext = new PuzzleViewModel(file);
			else
				DataContext = new MainViewModel();
			Model.PropertyChanged += Model_PropertyChanged;
		}

		private void Language_Click(object sender, RoutedEventArgs e)
		{
			var menu = sender as MenuItem;
			var model = Model as ComicsViewModel;
			if (menu.IsChecked && model != null)
				model.Culture = (Cultures)menu.DataContext;
			else
				BindingOperations.GetBindingExpressionBase(menu, MenuItem.IsCheckedProperty).UpdateTarget();
		}

		private void Window_Closed(object sender, EventArgs e)
		{
			Model.PropertyChanged -= Model_PropertyChanged;
			Model.Dispose();
		}
	}
}
