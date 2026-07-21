using Comics.DAL;
using Comics.DAL.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Admin.Models
{
	public class PuzzleModel
	{
		public Puzzle Item { get; set; }

		public void Load(Db db)
		{
		}

		public void Update(Db db)
		{
			var isNew = Item.Id == 0;
			Item.Update(db);
			db.SaveChanges();
			if (isNew)
			{
				Item.UpdateTokenKeys();
				db.SaveChanges();
			}
		}

		public static PuzzleModel Create(Db db, int? id)
		{
			var item = id.HasValue ? Puzzle.Load(db, id.Value) : Puzzle.Create(db);
			if (item == null)
				return null;

			var model = new PuzzleModel { Item = item };
			model.Load(db);
			return model;
		}
	}
}