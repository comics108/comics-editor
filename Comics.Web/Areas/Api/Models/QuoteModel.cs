using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Api.Models
{
	public class QuoteModel
	{
		public int Id { get; set; }

		public string Name { get; set; }

		public string Image { get; set; }
	}
}