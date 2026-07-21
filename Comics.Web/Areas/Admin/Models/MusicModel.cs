using Comics.DAL;
using Comics.DAL.Model;
using IWS.Utils;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Admin.Models
{
	public class MusicModel
	{
		public Music Item { get; set; }

		public HttpPostedFileBase AudioFile { get; set; }

		public void Load(Db db)
		{
		}

		public void Update(Db db)
		{
			var isNew = Item.Id == 0;
			Item.Update(db);
			Item.File = ImageManager.Update(Item.File, AudioFile, ImageManager.FolderFiles);
			db.SaveChanges();
			if (isNew)
			{
				Item.UpdateTokenKeys();
				db.SaveChanges();
			}
		}

		public static MusicModel Create(Db db, int? id)
		{
			var item = id.HasValue ? Music.Load(db, id.Value) : Music.Create(db);
			if (item == null)
				return null;

			var model = new MusicModel { Item = item };
			model.Load(db);
			return model;
		}
	}
}