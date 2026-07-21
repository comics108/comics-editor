using Comics.Editor.Models;
using Comics.Editor.ViewModel;
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
	/// Interaction logic for AnimControl.xaml
	/// </summary>
	public partial class AnimControl : UserControl
	{
		private ComicsViewModel MainModel
		{
			get { return Window.GetWindow(this)?.DataContext as ComicsViewModel; }
		}

		private Anim Model
		{
			get { return DataContext as Anim; }
		}

		public AnimControl()
		{
			InitializeComponent();
		}

		private void TextBox_Focus(object sender, RoutedEventArgs e)
		{
			var textBox = sender as TextBox;
			if (textBox == null || MainModel == null || Model == null)
				return;

			if (textBox.IsFocused)
				MainModel.Scroll = textBox == txtStart ? Model.Start : Model.End;
			else
			{
				int value;
				if (!int.TryParse(textBox.Text, out value))
					value = (int)MainModel.Scroll;
				if (textBox == txtStart)
					Model.Start = value;
				else
					Model.End = value;
				BindingOperations.GetBindingExpressionBase(textBox, TextBox.TextProperty).UpdateTarget();
			}
		}
	}
}
