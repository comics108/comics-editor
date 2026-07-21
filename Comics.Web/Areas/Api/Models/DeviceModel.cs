using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Api.Models
{
	public class DeviceModel
	{
		public string DeviceId { get; set; }

		public long LocalTime { get; set; }
	}

	public class TokenModel
	{
		/// <summary>
		/// Уникальный идентификатор девайса
		/// </summary>
		public string Token { get; set; }
	}
}