using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Net.Mail;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace IWS.Utils
{
	public static class Extensions
	{
		private static readonly DateTime UnixStart = new DateTime(1970, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc);
		private static readonly Random Rand = new Random();
		public static readonly JsonSerializerSettings SerializerSettings = new JsonSerializerSettings
		{
			ContractResolver = new CamelCasePropertyNamesContractResolver(),
			DefaultValueHandling = DefaultValueHandling.Ignore, // This solution is not compatible with iOS default values parsing from object fields Dictionary
			TypeNameHandling = TypeNameHandling.Auto
		};

		public static long ToUnixTimeStamp(this DateTime date, bool seconds = true)
		{
			var diff = (date.Kind == DateTimeKind.Unspecified ? date.ToLocalTime().ToUniversalTime() : date.ToUniversalTime()) - UnixStart;
			return (long)Math.Round(seconds ? diff.TotalSeconds : diff.TotalMilliseconds);
		}

		public static long? ToUnixTimeStamp(this DateTime? date, bool seconds = true)
		{
			return date.HasValue ? (long?)date.Value.ToUnixTimeStamp(seconds) : null;
		}

		public static DateTime FromUnixTimeStamp(this long value, bool seconds = true)
		{
			return seconds ? UnixStart.AddSeconds(value) : UnixStart.AddMilliseconds(value);
		}

		public static DateTime? FromUnixTimeStamp(this long? value, bool seconds = true)
		{
			return value.HasValue ? (DateTime?)value.Value.FromUnixTimeStamp(seconds) : null;
		}

		public static string Encrypt(this string str)
		{
			return string.IsNullOrEmpty(str) ? string.Empty : SymmetricCrypt.EncryptString(str);
		}

		public static string Decrypt(this string str)
		{
			return string.IsNullOrEmpty(str) ? string.Empty : SymmetricCrypt.DecryptString(str);
		}

		public static string ToJson(this object obj)
		{
			return JsonConvert.SerializeObject(obj, SerializerSettings);
		}

		public static T FromJson<T>(this string data)
		{
			try
			{
				return JsonConvert.DeserializeObject<T>(data, SerializerSettings);
			}
			catch
			{
				return default(T);
			}
		}

		public static object FromJson(this string data, Type type)
		{
			try
			{
				return JsonConvert.DeserializeObject(data, type, SerializerSettings);
			}
			catch
			{
				return null;
			}
		}

		public static TOutput[] ConvertAll<TInput, TOutput>(this TInput[] array, Converter<TInput, TOutput> converter)
		{
			return Array.ConvertAll(array, converter);
		}

		public static string GetFlagsName(this Enum value, string separator)
		{
			var result = new List<string>();
			foreach (Enum item in Enum.GetValues(value.GetType()))
			{
				if (value.HasFlag(item))
					result.Add(item.GetEnumName());
			}
			return string.Join(separator, result);
		}

		public static string GetEnumName(this Enum value)
		{
			var name = value.ToString();
			var field = value.GetType().GetField(name);
			if (field != null)
			{
				var attr = Attribute.GetCustomAttribute(field, typeof(DisplayAttribute)) as DisplayAttribute;
				if (attr != null)
					name = attr.Name;
			}
			return name;
		}

		public static bool IsValidPhone(this string phone)
		{
			return !string.IsNullOrEmpty(phone) && Regex.IsMatch(phone, @"^\+[0-9]{11,15}$", RegexOptions.IgnoreCase);
		}

		public static bool IsValidEmail(this string email)
		{
			try
			{
				var addr = new MailAddress(email);
				return addr.Address == email;
			}
			catch
			{
				return false;
			}
		}
	}
}
