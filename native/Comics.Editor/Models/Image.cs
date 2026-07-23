using Comics.Editor.Utils;
using IWS.Utils;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;

namespace Comics.Editor.Models
{
	public class Image : NotifyPropertyChanged
	{
		private string _file;
		private string _popup;

		public string File
		{
			get { return _file; }
			set
			{
				if (_file == value)
					return;
				_file = value;
				OnPropertyChanged(nameof(File));
			}
		}

		public string Popup
		{
			get { return _popup; }
			set
			{
				if (_popup == value)
					return;
				_popup = value;
				OnPropertyChanged(nameof(Popup));
			}
		}

		public int Width { get; set; }

		public int Height { get; set; }

		[JsonIgnore]
		public bool IsTiles
		{
			get { return !string.IsNullOrEmpty(File) && File.Contains("{0}"); }
		}

		public void Update(string folder, string file, bool puzzle, bool popup)
		{
			if (!FileManager.CheckFile(folder, popup ? Popup : File, file))
			{
				MessageBox.Show("File with this name already exists.", "Error");
				return;
			}

			if (popup)
			{
				Popup = FileManager.Update(folder, Popup, file);
				return;
			}

			File = FileManager.UpdateTiles(folder, File, file, puzzle, out var size);
			Width = size.Width;
			Height = size.Height;
		}

		public void Delete(string folder)
		{
			if (IsTiles)
				FileManager.DeleteTiles(folder, File);
			else
				FileManager.Delete(folder, File);
		}
	}
}
