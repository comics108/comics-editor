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
using System.Windows;
using System.Windows.Input;

namespace Comics.Editor.ViewModel
{
	public class ComicsViewModel : MainViewModel
	{
		private ICommand _saveCommand;
		private ICommand _addLayerCommand;
		private ICommand _addSoundCommand;
		private ICommand _convertCommand;

		private Models.Comics _comics = null;
		private ObservableCollection<LayerViewModel> _layers = null;
		private ObservableCollection<SoundViewModel> _sounds = null;
		private NotifyPropertyChanged _selectedItem = null;
		private Cultures _culture = Cultures.En;
		private double _scroll = 0;
		private bool _disableSound;

		public bool IsPuzzle
		{
			get { return this is PuzzleViewModel; }
		}

		public ICommand SaveCommand
		{
			get { return _saveCommand ?? (_saveCommand = new DelegateCommand(x => Save())); }
		}

		public ICommand AddLayerCommand
		{
			get { return _addLayerCommand ?? (_addLayerCommand = new DelegateCommand(x => AddLayer())); }
		}

		public ICommand AddSoundCommand
		{
			get { return _addSoundCommand ?? (_addSoundCommand = new DelegateCommand(x => AddSound())); }
		}

		public ICommand ConvertCommand
		{
			get { return _convertCommand ?? (_convertCommand = new DelegateCommand(x => Convert())); }
		}

		public Models.Comics Comics
		{
			get { return _comics; }
			set
			{
				if (_comics == value)
					return;
				_comics = value;
				SelectedItem = null;
				OnPropertyChanged(nameof(Comics));
				OnPropertyChanged(nameof(Width));
				OnPropertyChanged(nameof(Height));
				Layers = new ObservableCollection<LayerViewModel>(Comics.Layers.Select(x => new LayerViewModel(this, x)));
				Sounds = new ObservableCollection<SoundViewModel>(Comics.Sounds.Select(x => new SoundViewModel(this, x)));
			}
		}

		public int Width
		{
			get { return _comics.Width; }
			set
			{
				if (_comics.Width == value)
					return;
				_comics.Width = value;
				OnPropertyChanged(nameof(Width));
			}
		}

		public int Height
		{
			get { return _comics.Height; }
			set
			{
				if (_comics.Height == value)
					return;
				_comics.Height = value;
				OnPropertyChanged(nameof(Height));
			}
		}

		public ObservableCollection<LayerViewModel> Layers
		{
			get { return _layers; }
			private set
			{
				if (_layers == value)
					return;
				_layers = value;
				OnPropertyChanged(nameof(Layers));
			}
		}

		public ObservableCollection<SoundViewModel> Sounds
		{
			get { return _sounds; }
			private set
			{
				if (_sounds == value)
					return;
				_sounds = value;
				OnPropertyChanged(nameof(Sounds));
			}
		}

		public NotifyPropertyChanged SelectedItem
		{
			get { return _selectedItem; }
			set
			{
				if (_selectedItem == value)
					return;

				// reset selected anim on layer / sound deselect
				if (_selectedItem is LayerViewModel)
					((LayerViewModel)_selectedItem).SelectedAnim = null;
				else if (_selectedItem is SoundViewModel)
					((SoundViewModel)_selectedItem).SelectedAnim = null;

				// reset selected item to properly update the lists
				_selectedItem = null;
				OnPropertyChanged(nameof(SelectedItem));

				_selectedItem = value;
				OnPropertyChanged(nameof(SelectedItem));
			}
		}

		public Cultures Culture
		{
			get { return _culture; }
			set
			{
				if (_culture == value)
					return;
				_culture = value;
				OnPropertyChanged(nameof(Culture));
				foreach (var layer in Layers)
					layer.Culture();
			}
		}

		public double Scroll
		{
			get { return _scroll; }
			set
			{
				if (_scroll == value)
					return;
				_scroll = value;
				OnPropertyChanged(nameof(Scroll));
				foreach (var layer in Layers)
					layer.Scroll();
				foreach (var sound in Sounds)
					sound.Scroll();
			}
		}

		public bool DisableSound
		{
			get { return _disableSound; }
			set
			{
				if (_disableSound == value)
					return;
				_disableSound = value;
				OnPropertyChanged(nameof(DisableSound));
				foreach (var sound in Sounds)
					sound.Scroll();
			}
		}

		public ComicsViewModel(string file)
		{
			Opened = Visibility.Visible;
			File = file;
			FileManager.DeleteFolder();
			if (!string.IsNullOrEmpty(File) && !File.StartsWith("<"))
				ZipUtils.Unzip(File, FileManager.TempFolder);
			FileManager.CreateFolders();
			Comics = Models.Comics.Load();
		}

		public void Save()
		{
			if (string.IsNullOrEmpty(File) || File.StartsWith("<"))
			{
				var dlg = new SaveFileDialog();
				dlg.Filter = IsPuzzle ? "Puzzle files (*.puzzle)|*.puzzle" : "Comics files (*.comics)|*.comics";
				if (dlg.ShowDialog() != true)
					return;

				_file = dlg.FileName;
				OnPropertyChanged(nameof(Title));
			}

			Comics.Save();
			if (System.IO.File.Exists(File))
				System.IO.File.Delete(File);
			ZipUtils.Zip(Path.Combine(FileManager.TempFolder, "*"), File, 0);
		}

		public void AddLayer()
		{
			var dlg = new OpenFileDialog();
			dlg.Filter = "Image files (*.jpg, *.png)|*.jpg;*.png";
			if (dlg.ShowDialog() != true)
				return;

			var layer = Layer.Create(dlg.FileName, Scroll, IsPuzzle);
			if (layer == null)
				return;

			Comics.Layers.Add(layer);
			Layers.Add(new LayerViewModel(this, layer));
			SelectedItem = Layers.LastOrDefault();
		}

		public void AddSound()
		{
			var dlg = new OpenFileDialog();
			dlg.Filter = "Audio files (*.mp3)|*.mp3";
			if (dlg.ShowDialog() != true)
				return;

			var sound = Sound.Create(dlg.FileName, Scroll);
			Comics.Sounds.Add(sound);
			Sounds.Add(new SoundViewModel(this, sound));
			SelectedItem = Sounds.LastOrDefault();
		}

		public void Convert()
		{
			// TODO remove convert functionality
			var backgrounds = Path.Combine(FileManager.TempFolder, "backgrounds");
			if (Directory.Exists(backgrounds))
				Directory.Delete(backgrounds, true);

			var convertFolder = Path.Combine(FileManager.TempFolder, "temp");
			Directory.CreateDirectory(convertFolder);
			foreach (var layer in Comics.Layers)
				foreach (var image in layer.Images)
				{
					if (string.IsNullOrEmpty(image.File) || image.IsTiles)
						continue;

					var file = Path.Combine(convertFolder, image.File);
					System.IO.File.Copy(Path.Combine(FileManager.TempFolder, FileManager.FolderLayers, image.File), file);
					image.Update(FileManager.FolderLayers, file, IsPuzzle, false);
				}
			Directory.Delete(convertFolder, true);
		}

		private void DisposeSounds()
		{
			if (Sounds == null)
				return;

			foreach (var sound in Sounds)
				sound.Dispose();
		}

		public override void Dispose()
		{
			DisposeSounds();
		}
	}
}
