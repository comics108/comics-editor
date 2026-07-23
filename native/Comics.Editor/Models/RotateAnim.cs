using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;

namespace Comics.Editor.Models
{
	public class RotateAnim : PivotAnim
	{
		private double _angle;

		public override AnimTypes Type
		{
			get { return AnimTypes.Rotate; }
		}

		public double Angle
		{
			get { return _angle; }
			set
			{
				if (_angle == value)
					return;
				_angle = value;
				OnPropertyChanged(nameof(Angle));
			}
		}

		public override Anim Interpolate(Anim current, double scroll)
		{
			var rotate = (RotateAnim)current;
			return new RotateAnim
			{
				Angle = Angle + (rotate.Angle - Angle) * rotate.Factor(scroll),
				PivotX = rotate.PivotX,
				PivotY = rotate.PivotY
			};
		}
	}
}
