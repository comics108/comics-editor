using IWS.Utils;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Api.Models
{
	public class EpisodeModel
	{
		public int Id { get; set; }

		public string Name { get; set; }

		public string Image { get; set; }

		public string File { get; set; }

		/// <summary>
		/// Версия эпизода. Используется для механизма обновлений
		/// </summary>
		public int Version { get; set; }

		/// <summary>
		/// Имя продукта для покупки в Google Play / App Store или null, если эпизод бесплатный
		/// </summary>
		public string Product { get; set; }

		/// <summary>
		/// Дата выпуска эпизода. Используется для подписок
		/// </summary>
		[JsonConverter(typeof(EpochDateTimeConverter))]
		public DateTime Date { get; set; }

		public int Order { get; set; }
	}
}