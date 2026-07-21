using Comics.DAL;
using Comics.DAL.Model;
using IWS.Utils;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Admin.Models
{
	public class QuoteModel
	{
		public Quote Item { get; set; }

		public HttpPostedFileBase[] ImageFile { get; set; }

		public void Load(Db db)
		{
		}

		public void Update(Db db)
		{
			var isNew = Item.Id == 0;
			Item.Update(db);
			for (int i = 0; i < ImageFile.Length; i++)
				Item.ImageToken.LocalizedTokens[i].Text = ImageManager.Update(Item.ImageToken.LocalizedTokens[i].Text, ImageFile[i]);
			db.SaveChanges();
			if (isNew)
			{
				Item.UpdateTokenKeys();
				db.SaveChanges();
			}
		}

		public static QuoteModel Create(Db db, int? id)
		{
			var item = id.HasValue ? Quote.Load(db, id.Value) : Quote.Create(db);
			if (item == null)
				return null;

			var model = new QuoteModel { Item = item };
			model.Load(db);
			return model;
		}
	}
}