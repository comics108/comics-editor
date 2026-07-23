using Comics.Editor.Models;
using Microsoft.Win32;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;

namespace Comics.Editor.ViewModel
{
	public class LayerViewModel : NotifyPropertyChanged
	{
		private ICommand _changeCommand;
		private ICommand _popupCommand;
		private ICommand _moveCommand;
		private ICommand _deleteCommand;
		private ICommand _addAnimCommand;
		private ICommand _deleteAnimCommand;

		private Layer _layer;
		private Image _image;
		private TranslateAnim _translate;
		private RotateAnim _rotate;
		private ScaleAnim _scale;
		private AlphaAnim _alpha;
		private Anim _selectedAnim;
		private bool _isVisible = true;

		public ICommand ChangeCommand
		{
			get { return _changeCommand ?? (_changeCommand = new DelegateCommand(x => Change((Cultures)x, false))); }
		}

		public ICommand PopupCommand
		{
			get { return _popupCommand ?? (_popupCommand = new DelegateCommand(x => Change((Cultures)x, true))); }
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
			get { return _addAnimCommand ?? (_addAnimCommand = new DelegateCommand(x => AddAnim((AnimTypes)x))); }
		}

		public ICommand DeleteAnimCommand
		{
			get { return _deleteAnimCommand ?? (_deleteAnimCommand = new DelegateCommand(x => DeleteAnim())); }
		}

		public ComicsViewModel Parent { get; private set; }

		public Layer Layer
		{
			get { return _layer; }
			private set
			{
				if (_layer == value)
					return;
				_layer = value;
				OnPropertyChanged(nameof(Layer));
			}
		}

		public Image Image
		{
			get { return _image; }
			set
			{
				if (_image == value)
					return;
				_image = value;
				OnPropertyChanged(nameof(Image));
			}
		}

		public TranslateAnim Translate
		{
			get { return _translate; }
			set
			{
				if (_translate == value)
					return;
				_translate = value;
				OnPropertyChanged(nameof(Translate));
			}
		}

		public RotateAnim Rotate
		{
			get { return _rotate; }
			set
			{
				if (_rotate == value)
					return;
				_rotate = value;
				OnPropertyChanged(nameof(Rotate));
			}
		}

		public ScaleAnim Scale
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

		public AlphaAnim Alpha
		{
			get { return _alpha; }
			set
			{
				if (_alpha == value)
					return;
				_alpha = value;
				OnPropertyChanged(nameof(Alpha));
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
				// scroll to the end of animation or to layer position if it is the default translate animation.
				if (_selectedAnim != null)
					Parent.Scroll = _selectedAnim.End == 0 && _selectedAnim is TranslateAnim ? Math.Max(((TranslateAnim)_selectedAnim).Y - 1000, 0) : _selectedAnim.End;
			}
		}

		public bool IsVisible
		{
			get { return _isVisible; }
			set
			{
				if (_isVisible == value)
					return;
				_isVisible = value;
				OnPropertyChanged(nameof(IsVisible));
				OnPropertyChanged(nameof(Visibility));
			}
		}

		public Visibility Visibility
		{
			get { return IsVisible ? Visibility.Visible : Visibility.Collapsed; }
		}

		public LayerViewModel(ComicsViewModel parent, Layer layer)
		{
			Parent = parent;
			Layer = layer;
			Culture();
			Scroll();
		}

		public void Culture()
		{
			Image = Layer.GetImage(Parent.Culture);
		}

		public void Scroll()
		{
			var scroll = Parent.Scroll;
			Translate = Anim.Interpolate<TranslateAnim>(Layer.Animations, SelectedAnim, scroll);
			Rotate = Anim.Interpolate<RotateAnim>(Layer.Animations, SelectedAnim, scroll);
			Scale = Anim.Interpolate<ScaleAnim>(Layer.Animations, SelectedAnim, scroll);
			Alpha = Anim.Interpolate<AlphaAnim>(Layer.Animations, SelectedAnim, scroll);
		}

		public void Change(Cultures culture, bool popup)
		{
			var dlg = new OpenFileDialog();
			dlg.Filter = "Image files (*.jpg, *.png)|*.jpg;*.png";
			if (dlg.ShowDialog() != true)
				return;

			Layer.SetImage(culture, dlg.FileName, Parent.IsPuzzle, popup);
			OnPropertyChanged(nameof(Image));
		}

		public void Move(int offset)
		{
			var index = Parent.Layers.IndexOf(this);
			var newIndex = index >= 0 ? index + offset : -1;
			if (newIndex >= 0 && newIndex < Parent.Layers.Count)
			{
				Parent.Layers.Move(index, newIndex);
				Parent.Comics.Layers.RemoveAt(index);
				Parent.Comics.Layers.Insert(newIndex, Layer);
			}
		}

		public void Delete()
		{
			Layer.Delete();
			Parent.Comics.Layers.Remove(Layer);
			Parent.Layers.Remove(this);
			Parent.SelectedItem = null;
		}

		public void AddAnim(AnimTypes type)
		{
			SelectedAnim = Anim.Add(Layer.Animations, type, Parent.Scroll);
		}

		public void DeleteAnim()
		{
			if (SelectedAnim == null)
				return;

			Layer.Animations.Remove(SelectedAnim);
			SelectedAnim = null;
		}
	}
}
