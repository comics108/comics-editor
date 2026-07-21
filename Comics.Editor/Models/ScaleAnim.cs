using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;

namespace Comics.Editor.Models
{
	public class ScaleAnim : PivotAnim
	{
		private double _scaleX;
		private double _scaleY;

		public override AnimTypes Type
		{
			get { return AnimTypes.Scale; }
		}

		public double ScaleX
		{
			get { return _scaleX; }
			set
			{
				if (_scaleX == value)
					return;
				_scaleX = value;
				OnPropertyChanged(nameof(ScaleX));
			}
		}

		public double ScaleY
		{
			get { return _scaleY; }
			set
			{
				if (_scaleY == value)
					return;
				_scaleY = value;
				OnPropertyChanged(nameof(ScaleY));
			}
		}

		public override Anim Interpolate(Anim current, double scroll)
		{
			var scale = (ScaleAnim)current;
			return new ScaleAnim
			{
				ScaleX = ScaleX + (scale.ScaleX - ScaleX) * scale.Factor(scroll),
				ScaleY = ScaleY + (scale.ScaleY - ScaleY) * scale.Factor(scroll),
				PivotX = scale.PivotX,
				PivotY = scale.PivotY
			};
		}

		protected override void Init()
		{
			base.Init();
			_scaleX = 1;
			_scaleY = 1;
		}
	}
}
