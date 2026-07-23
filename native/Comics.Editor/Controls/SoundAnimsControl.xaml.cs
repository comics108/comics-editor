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
	/// Interaction logic for SoundAnimsControl.xaml
	/// </summary>
	public partial class SoundAnimsControl : UserControl
	{
		private SoundViewModel Model
		{
			get { return DataContext as SoundViewModel; }
		}

		public SoundAnimsControl()
		{
			InitializeComponent();
		}

		private void Button_Click(object sender, RoutedEventArgs e)
		{
			var btn = sender as ToggleButton;
			Model.Parent.SelectedItem = Model;
			Model.SelectedAnim = btn?.IsChecked == true ? btn?.DataContext as SoundAnim : null;
		}

		private void Thumb_DragDelta(object sender, DragDeltaEventArgs e)
		{
			var thumb = sender as Thumb;
			var anim = Model.SelectedAnim;
			if (thumb == null || anim == null)
				return;

			if (thumb.VerticalAlignment == VerticalAlignment.Top)
				anim.Start = Math.Min(anim.Start + (int)e.VerticalChange, anim.End);
			else if (thumb.VerticalAlignment == VerticalAlignment.Bottom)
				anim.End = Math.Max(anim.End + (int)e.VerticalChange, anim.Start);
			else
			{
				anim.Start += (int)e.VerticalChange;
				anim.End += (int)e.VerticalChange;
			}
		}
	}
}
