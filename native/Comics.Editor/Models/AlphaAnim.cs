using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Comics.Editor.Models
{
	public class AlphaAnim : Anim
	{
		private double _alpha;

		public override AnimTypes Type
		{
			get { return AnimTypes.Alpha; }
		}

		public double Alpha
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

		public override Anim Interpolate(Anim current, double scroll)
		{
			var alpha = (AlphaAnim)current;
			return new AlphaAnim
			{
				Alpha = Alpha + (alpha.Alpha - Alpha) * alpha.Factor(scroll)
			};
		}

		protected override void Init()
		{
			base.Init();
			_alpha = 1;
		}
	}
}
