using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;

namespace Comics.Editor.Models
{
	public abstract class PivotAnim : Anim
	{
		private double _pivotX;
		private double _pivotY;

		public double PivotX
		{
			get { return _pivotX; }
			set
			{
				if (_pivotX == value)
					return;
				_pivotX = value;
				OnPropertyChanged(nameof(PivotX));
				OnPropertyChanged(nameof(Pivot));
			}
		}

		public double PivotY
		{
			get { return _pivotY; }
			set
			{
				if (_pivotY == value)
					return;
				_pivotY = value;
				OnPropertyChanged(nameof(PivotY));
				OnPropertyChanged(nameof(Pivot));
			}
		}

		[JsonIgnore]
		public Point Pivot
		{
			get { return new Point(PivotX, PivotY); }
		}

		protected override void Init()
		{
			base.Init();
			_pivotX = 0.5;
			_pivotY = 0.5;
		}
	}
}
