using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Comics.Editor.Models
{
	public enum Cultures
	{
		En,
		Ru,
		Hi
	}

	public class CulturesHelper
	{
		public static readonly List<Cultures> All = Enum.GetValues(typeof(Cultures)).OfType<Cultures>().ToList();
	}
}
