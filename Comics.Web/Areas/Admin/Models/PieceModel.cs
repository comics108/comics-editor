using Comics.DAL;
using Comics.DAL.Model;
using IWS.Utils;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Admin.Models
{
	public class PieceModel
	{
		public Piece Item { get; set; }

		public HttpPostedFileBase ArchiveFile { get; set; }

		public void Load(Db db)
		{
			if (Item.Puzzle == null)
				Item.Puzzle = Puzzle.Load(db, Item.PuzzleId);
		}

		public void Update(Db db)
		{
			Item.Update(db);
			Item.File = ImageManager.Update(Item.File, ArchiveFile, ImageManager.FolderFiles);
			db.SaveChanges();
		}

		public static PieceModel Create(Db db, int? id, int? puzzleId)
		{
			var item = id.HasValue ? Piece.Load(db, id.Value) : Piece.Create(db, puzzleId);
			if (item == null)
				return null;

			var model = new PieceModel { Item = item };
			model.Load(db);
			return model;
		}
	}
}