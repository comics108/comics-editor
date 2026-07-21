using Comics.DAL.Model;
using IWS.Mvc;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Admin.Models
{
	public enum QuoteStatuses
	{
		All,
		Published,
		Unpublished
	}

	public class QuotesParams : ListParams
	{
		public QuoteStatuses? Status { get; set; }

		protected override void Update(ListParams savedParams, bool post)
		{
			base.Update(savedParams, post);
			var param = (QuotesParams)savedParams;
			if (!Status.HasValue)
				Status = param?.Status ?? QuoteStatuses.All;
		}

		public override IQueryable<T> Filter<T>(IQueryable<T> query)
		{
			var result = (IQueryable<Quote>)query;
			if (Status == QuoteStatuses.Published)
				result = result.Where(x => x.PublishDate.HasValue);
			else if (Status == QuoteStatuses.Unpublished)
				result = result.Where(x => !x.PublishDate.HasValue);
			return (IQueryable<T>)result;
		}

		public override string OrderBy()
		{
			return "PublishDate";
		}
	}
}