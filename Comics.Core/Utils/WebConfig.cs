using System;
using System.Configuration;

namespace IWS.Utils
{
	public static class WebConfig
	{
		public static string ConnectionString
		{
			get
			{
				return ConfigurationManager.ConnectionStrings["Db"].ConnectionString;
			}
		}

		public static bool MigrationEnabled
		{
			get { return GetSetting<bool>("MigrationEnabled"); }
		}

		public static string AllowedIps
		{
			get { return GetSetting<string>("AllowedIps"); }
		}

		public static string AdminUser
		{
			get { return GetSetting<string>("AdminUser"); }
		}

		public static string AdminPassword
		{
			get { return GetSetting<string>("AdminPassword"); }
		}

		public static string[] Subscriptions
		{
			get { return GetSetting<string>("Subscriptions").Split(','); }
		}

		public static bool IsApnProduction
		{
			get { return GetSetting<bool>("IsApnProduction"); }
		}

		public static string ApnProdCert
		{
			get { return GetSetting<string>("ApnProdCert"); }
		}

		public static string ApnDevCert
		{
			get { return GetSetting<string>("ApnDevCert"); }
		}

		public static string FcmApiKey
		{
			get { return GetSetting<string>("FcmApiKey"); }
		}

		private static T GetSetting<T>(string name)
		{
			var value = ConfigurationManager.AppSettings[name];
			if (typeof(T) == typeof(int))
				return (T)(object)Convert.ToInt32(value);
			if (typeof(T) == typeof(bool))
				return (T)(object)Convert.ToBoolean(value);
			return (T)(object)value;
		}
	}
}