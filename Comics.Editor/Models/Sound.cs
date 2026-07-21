using Comics.Editor.Utils;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Comics.Editor.Models
{
	public class Sound : NotifyPropertyChanged
	{
		private string _file;

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

		public ObservableCollection<Anim> Animations { get; set; } = new ObservableCollection<Anim>();

		public void Delete()
		{
			FileManager.Delete(FileManager.FolderSounds, File);
		}

		public static Sound Create(string file, double scroll)
		{
			var sound = new Sound
			{
				File = FileManager.Update(FileManager.FolderSounds, null, file)
			};
			sound.Animations.Add(new SoundAnim { Start = (int)scroll, End = (int)scroll });
			return sound;
		}
	}
}
