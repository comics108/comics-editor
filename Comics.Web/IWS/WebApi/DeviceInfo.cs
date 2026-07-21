using IWS.Utils;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http.Headers;
using System.Text.RegularExpressions;
using System.Web;

namespace IWS.WebApi
{
	public class DeviceInfo
	{
		public PlatformTypes Platform { get; set; }

		public string OsVersion { get; set; }

		public string Model { get; set; }

		public string AppId { get; set; }

		public string AppVersion { get; set; }

		public Version ParseVersion()
		{
			Version version;
			return Version.TryParse(AppVersion, out version) ? version : null;
		}

		public bool IsValid()
		{
			return Platform != PlatformTypes.None && !string.IsNullOrEmpty(OsVersion) && !string.IsNullOrEmpty(Model) && !string.IsNullOrEmpty(AppId) && !string.IsNullOrEmpty(AppVersion);
		}

		public static DeviceInfo Create(HttpHeaderValueCollection<ProductInfoHeaderValue> userAgent)
		{
			var product = userAgent.Where(x => x.Product != null).Select(x => x.Product).FirstOrDefault();
			var comment = userAgent.Where(x => x.Comment != null).Select(x => x.Comment).FirstOrDefault();
			if (product == null || comment == null)
				return null;

			var match = Regex.Match(comment, @"\((.+)\;\s(\w+)\s(.+)\)");
			if (!match.Success || match.Groups.Count != 4)
				return null;

			var device = new DeviceInfo
			{
				Model = match.Groups[1].Value,
				OsVersion = match.Groups[3].Value,
				AppId = product.Name,
				AppVersion = product.Version
			};

			PlatformTypes platform;
			if (!Enum.TryParse(match.Groups[2].Value, true, out platform))
				platform = PlatformTypes.None;
			device.Platform = platform;

			return device.IsValid() ? device : null;
		}
	}
}