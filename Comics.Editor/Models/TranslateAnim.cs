using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Comics.Editor.Models
{
	public class TranslateAnim : Anim
	{
		private int _x;
		private int _y;

		public override AnimTypes Type
		{
			get { return AnimTypes.Translate; }
		}

		public int X
		{
			get { return _x; }
			set
			{
				if (_x == value)
					return;
				_x = value;
				OnPropertyChanged(nameof(X));
			}
		}

		public int Y
		{
			get { return _y; }
			set
			{
				if (_y == value)
					return;
				_y = value;
				OnPropertyChanged(nameof(Y));
			}
		}

		public override Anim Interpolate(Anim current, double scroll)
		{
			var translate = (TranslateAnim)current;
			return new TranslateAnim
			{
				X = (int)Math.Round(X + (translate.X - X) * translate.Factor(scroll)),
				Y = (int)Math.Round(Y + (translate.Y - Y) * translate.Factor(scroll))
			};
		}
	}
}
