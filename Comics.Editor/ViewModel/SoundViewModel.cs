using Comics.Editor.Models;
using Comics.Editor.Utils;
using Microsoft.Win32;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Input;
using System.Windows.Media;

namespace Comics.Editor.ViewModel
{
	public class SoundViewModel : NotifyPropertyChanged, IDisposable
	{
		private ICommand _changeCommand;
		private ICommand _moveCommand;
		private ICommand _deleteCommand;
		private ICommand _addAnimCommand;
		private ICommand _deleteAnimCommand;

		private Sound _sound;
		private Anim _selectedAnim;
		private double _scroll;
		private readonly MediaPlayer _player;
		private PlayerState _state;

		public ICommand ChangeCommand
		{
			get { return _changeCommand ?? (_changeCommand = new DelegateCommand(x => Change())); }
		}

		public ICommand MoveCommand
		{
			get { return _moveCommand ?? (_moveCommand = new DelegateCommand(x => Move((int)x))); }
		}

		public ICommand DeleteCommand
		{
			get { return _deleteCommand ?? (_deleteCommand = new DelegateCommand(x => Delete())); }
		}

		public ICommand AddAnimCommand
		{
			get { return _addAnimCommand ?? (_addAnimCommand = new DelegateCommand(x => AddAnim())); }
		}

		public ICommand DeleteAnimCommand
		{
			get { return _deleteAnimCommand ?? (_deleteAnimCommand = new DelegateCommand(x => DeleteAnim())); }
		}

		public ComicsViewModel Parent { get; private set; }

		public Sound Sound
		{
			get { return _sound; }
			private set
			{
				if (_sound == value)
					return;
				_sound = value;
				OnPropertyChanged(nameof(Sound));
				Load();
			}
		}

		public Anim SelectedAnim
		{
			get { return _selectedAnim; }
			set
			{
				if (_selectedAnim == value)
					return;
				_selectedAnim = value;
				OnPropertyChanged(nameof(SelectedAnim));
			}
		}

		public SoundViewModel(ComicsViewModel parent, Sound sound)
		{
			_player = new MediaPlayer();
			_player.MediaEnded += Player_MediaEnded;

			Parent = parent;
			Sound = sound;
			Scroll();
		}

		private void Player_MediaEnded(object sender, EventArgs e)
		{
			if (_state == PlayerState.Looping)
				Play(_state, true);
			else
				_state = PlayerState.Stopped;
		}

		private void Load()
		{
			Stop();
			_player.Open(new Uri(Path.Combine(FileManager.TempFolder, FileManager.FolderSounds, Sound.File)));
		}

		private void Play(PlayerState state, bool force = false)
		{
			if (_state == PlayerState.Stopped || force)
			{
				_player.Position = TimeSpan.Zero;
				_player.Play();
				_state = state;
			}
		}

		private void Stop()
		{
			if (_state != PlayerState.Stopped)
			{
				_player.Stop();
				_state = PlayerState.Stopped;
			}
		}

		public void Scroll()
		{
			if (Parent.DisableSound)
			{
				Stop();
				return;
			}

			var anim = SoundAnim.FindCurrent(Sound.Animations, _scroll, Parent.Scroll);
			_scroll = Parent.Scroll;
			if (anim != null)
				Play(anim.Start == anim.End ? PlayerState.Playing : PlayerState.Looping);
			else if (_state == PlayerState.Looping)
				Stop();
		}

		public void Change()
		{
			var dlg = new OpenFileDialog();
			dlg.Filter = "Audio files (*.mp3)|*.mp3";
			if (dlg.ShowDialog() != true)
				return;

			Sound.File = FileManager.Update(FileManager.FolderSounds, Sound.File, dlg.FileName);
			Load();
		}

		public void Move(int offset)
		{
			var index = Parent.Sounds.IndexOf(this);
			var newIndex = index >= 0 ? index + offset : -1;
			if (newIndex >= 0 && newIndex < Parent.Sounds.Count)
			{
				Parent.Sounds.Move(index, newIndex);
				Parent.Comics.Sounds.RemoveAt(index);
				Parent.Comics.Sounds.Insert(newIndex, Sound);
			}
		}

		public void Delete()
		{
			Dispose();
			Sound.Delete();
			Parent.Comics.Sounds.Remove(Sound);
			Parent.Sounds.Remove(this);
			Parent.SelectedItem = null;
		}

		public void AddAnim()
		{
			SelectedAnim = Anim.Add<SoundAnim>(Sound.Animations, Parent.Scroll);
		}

		public void DeleteAnim()
		{
			if (SelectedAnim == null)
				return;

			Sound.Animations.Remove(SelectedAnim);
			SelectedAnim = null;
		}

		public void Dispose()
		{
			Stop();
			_player.Close();
			_player.MediaEnded -= Player_MediaEnded;
		}

		private enum PlayerState
		{
			Stopped,
			Playing,
			Looping
		}
	}
}
