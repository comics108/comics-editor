using Comics.Editor.Models;
using Comics.Editor.Utils;
using Microsoft.Win32;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Input;

namespace Comics.Editor.ViewModel
{
	public class PuzzleViewModel : ComicsViewModel
	{
		private double _scale = 0.5;

		public double Scale
		{
			get { return _scale; }
			set
			{
				if (_scale == value)
					return;
				_scale = value;
				OnPropertyChanged(nameof(Scale));
			}
		}

		public PuzzleViewModel(string file)
			: base(file)
		{
		}
	}
}
