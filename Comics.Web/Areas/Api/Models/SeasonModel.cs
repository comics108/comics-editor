using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Api.Models
{
	public class SeasonModel
	{
		public int Id { get; set; }

		public string Name { get; set; }

		public string Image { get; set; }

		public string Product { get; set; }

		public int Order { get; set; }

		public List<EpisodeModel> Episodes { get; set; }
	}
}