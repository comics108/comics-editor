using Comics.DAL;
using Comics.DAL.Model;
using IWS.Utils;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Admin.Models
{
	public class EpisodeModel
	{
		public Episode Item { get; set; }

		public HttpPostedFileBase ImageFile { get; set; }

		public HttpPostedFileBase ArchiveFile { get; set; }

		public void Load(Db db)
		{
			if (Item.Season == null)
				Item.Season = Season.Load(db, Item.SeasonId);
		}

		public void Update(Db db)
		{
			var isNew = Item.Id == 0;
			Item.Update(db);
			Item.Image = ImageManager.Update(Item.Image, ImageFile, sizes: Episode.ImageSize);
			Item.File = ImageManager.Update(Item.File, ArchiveFile, ImageManager.FolderFiles);
			db.SaveChanges();
			if (isNew)
			{
				Item.UpdateTokenKeys();
				db.SaveChanges();
			}
		}

		public static EpisodeModel Create(Db db, int? id, int? seasonId)
		{
			var item = id.HasValue ? Episode.Load(db, id.Value) : Episode.Create(db, seasonId);
			if (item == null)
				return null;

			var model = new EpisodeModel { Item = item };
			model.Load(db);
			return model;
		}
	}
}