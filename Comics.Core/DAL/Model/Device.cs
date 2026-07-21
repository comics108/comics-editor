using IWS.Utils;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Comics.DAL.Model
{
	public class Device
	{
		[Key]
		public Guid Id { get; set; }

		public PlatformTypes Platform { get; set; }

		[Required]
		[StringLength(32)]
		public string OsVersion { get; set; }

		[Required]
		[StringLength(256)]
		public string DeviceId { get; set; }

		[Required]
		[StringLength(256)]
		public string Model { get; set; }

		[Required]
		[StringLength(32)]
		public string AppVersion { get; set; }

		public int TimezoneOffset { get; set; }

		public Cultures Culture { get; set; }

		[MaxLength]
		public string PushToken { get; set; }

		public DateTime LastModified { get; set; }

		public static Device Update(Db db, Guid token, PlatformTypes platform, string osVersion, string deviceId, string deviceModel, string appVersion, int tzOffset, Cultures culture)
		{
			var device = (token != Guid.Empty ? db.Devices.FirstOrDefault(x => x.Id == token) : null) ??
				db.Devices.FirstOrDefault(x => x.DeviceId == deviceId && x.Platform == platform && x.OsVersion == osVersion);
			if (device == null)
			{
				device = new Device { Id = Guid.NewGuid() };
				db.Devices.Add(device);
			}

			device.Platform = platform;
			device.OsVersion = osVersion;
			device.DeviceId = deviceId;
			device.Model = deviceModel;
			device.AppVersion = appVersion;
			device.TimezoneOffset = tzOffset;
			device.Culture = culture;
			device.LastModified = DateTime.UtcNow;
			db.SaveChanges();
			return device;
		}

		public static Device Load(Db db, Guid id)
		{
			return db.Devices.FirstOrDefault(x => x.Id == id);
		}

		public static IQueryable<Device> LoadPush(Db db)
		{
			return db.Devices.AsNoTracking().Where(x => x.Platform != PlatformTypes.None && !string.IsNullOrEmpty(x.PushToken));
		}

		public static void UpdatePushToken(string oldToken, string newToken)
		{
			using (var db = new Db())
			{
				var device = db.Devices.FirstOrDefault(x => x.PushToken == oldToken);
				if (device != null)
				{
					device.PushToken = newToken;
					db.SaveChanges();
				}
			}
		}
	}
}