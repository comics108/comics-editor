using Comics.DAL;
using Comics.DAL.Model;
using IWS.Mvc;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Admin.Models
{
	public class EpisodesParams : ListParams
	{
		[Display(Name = "Season")]
		public int? SeasonId { get; set; }

		public List<Season> Seasons { get; set; }

		protected override void Update(ListParams savedParams, bool post)
		{
			base.Update(savedParams, post);
			var param = (EpisodesParams)savedParams;
			if (!SeasonId.HasValue)
				SeasonId = param?.SeasonId;
		}

		public override IQueryable<T> Filter<T>(IQueryable<T> query)
		{
			var result = (IQueryable<Episode>)query;
			if (SeasonId > 0)
				result = result.Where(x => x.SeasonId == SeasonId.Value);

			return (IQueryable<T>)result;
		}

		public override string OrderBy()
		{
			return "SeasonId, Order";
		}

		public void Load(Db db)
		{
			Seasons = Season.Load(db).ToList();
			if (!SeasonId.HasValue)
				SeasonId = Seasons.FirstOrDefault()?.Id;
		}
	}
}