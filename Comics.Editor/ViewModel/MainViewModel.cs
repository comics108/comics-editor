using Comics.Editor.Models;
using Microsoft.Win32;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;

namespace Comics.Editor.ViewModel
{
	public class MainViewModel : NotifyPropertyChanged, IDisposable
	{
		private ICommand _openCommand;
		private ICommand _exitCommand;

		protected string _file;

		public ICommand OpenCommand
		{
			get { return _openCommand ?? (_openCommand = new DelegateCommand(x => Open(x as string))); }
		}

		public ICommand ExitCommand
		{
			get { return _exitCommand ?? (_exitCommand = new DelegateCommand(x => Exit())); }
		}

		public string File
		{
			get { return _file; }
			protected set
			{
				_file = value;
				OnPropertyChanged(nameof(File));
				OnPropertyChanged(nameof(Title));
			}
		}

		public string Title
		{
			get { return "Comics Editor " + Assembly.GetExecutingAssembly().GetName().Version.ToString(2) + (!string.IsNullOrEmpty(File) ? " - " + File : string.Empty); }
		}

		public Visibility Opened { get; set; } = Visibility.Collapsed;

		public void Open(string file)
		{
			if (!string.IsNullOrEmpty(file))
			{
				File = file;
				return;
			}

			var dlg = new OpenFileDialog();
			dlg.Filter = "Comics and puzzle files (*.comics, *.puzzle)|*.comics;*.puzzle";
			if (dlg.ShowDialog() == true)
				File = dlg.FileName;
		}

		public void Exit()
		{
			Application.Current.Shutdown();
		}

		public virtual void Dispose()
		{
			ResetPropertyChanged();
		}
	}
}
