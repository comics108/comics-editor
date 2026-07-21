using Comics.DAL;
using Comics.DAL.Model;
using IWS.Utils;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Admin.Models
{
	public class SeasonModel
	{
		public Season Item { get; set; }

		public HttpPostedFileBase ImageFile { get; set; }

		public void Load(Db db)
		{
		}

		public void Update(Db db)
		{
			var isNew = Item.Id == 0;
			Item.Update(db);
			Item.Image = ImageManager.Update(Item.Image, ImageFile);
			db.SaveChanges();
			if (isNew)
			{
				Item.UpdateTokenKeys();
				db.SaveChanges();
			}
		}

		public static SeasonModel Create(Db db, int? id)
		{
			var item = id.HasValue ? Season.Load(db, id.Value) : Season.Create(db);
			if (item == null)
				return null;

			var model = new SeasonModel { Item = item };
			model.Load(db);
			return model;
		}
	}
}