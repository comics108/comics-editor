using IWS.Mvc;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Admin.Models
{
	public class MusicParams : ListParams
	{
		public override string OrderBy()
		{
			return "Order";
		}
	}
}