using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IWS.Utils
{
	public enum PlatformTypes
	{
		None,
		Android,
		iOS,
		WindowsPhone
	}

	public static class PlatformTypesHelper
	{
		public static readonly List<PlatformTypes> All = Enum.GetValues(typeof(PlatformTypes)).OfType<PlatformTypes>().Where(x => x != PlatformTypes.None).ToList();
	}
}
