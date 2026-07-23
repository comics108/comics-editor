using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Comics.Editor.Models
{
	public class SoundAnim : Anim
	{
		public override AnimTypes Type
		{
			get { return AnimTypes.Sound; }
		}

		public override Anim Interpolate(Anim current, double scroll)
		{
			return current;
		}

		public static SoundAnim FindCurrent(ObservableCollection<Anim> anims, double prevScroll, double scroll)
		{
			return anims.OfType<SoundAnim>().FirstOrDefault(x => x.Start <= scroll && x.End >= scroll || x.Start == x.End && prevScroll < scroll && prevScroll <= x.Start && x.Start <= scroll);
		}
	}
}
