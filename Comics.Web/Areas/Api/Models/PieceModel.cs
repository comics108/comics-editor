using IWS.Utils;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Api.Models
{
	public class PieceModel
	{
		public int Id { get; set; }

		public int X { get; set; }

		public int Y { get; set; }

		public int Width { get; set; }

		public int Height { get; set; }

		public string File { get; set; }

		public int Version { get; set; }

		[JsonConverter(typeof(EpochDateTimeConverter))]
		public DateTime Date { get; set; }

		public int Order { get; set; }
	}
}