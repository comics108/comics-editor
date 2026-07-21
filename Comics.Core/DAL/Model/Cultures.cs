using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Comics.DAL.Model
{
	public enum Cultures
	{
		En,
		Ru
	}

	public class CulturesHelper
	{
		public static readonly Cultures[] All = Enum.GetValues(typeof(Cultures)).OfType<Cultures>().ToArray();

		public static Cultures Current
		{
			get
			{
				Cultures culture;
				if (!Enum.TryParse(CultureInfo.CurrentUICulture.TwoLetterISOLanguageName, true, out culture))
					culture = Cultures.En;
				return culture;
			}
		}
	}
}
