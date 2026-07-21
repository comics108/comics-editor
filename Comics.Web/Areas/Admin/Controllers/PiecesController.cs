using Comics.DAL;
using Comics.DAL.Model;
using Comics.Web.Areas.Admin.Models;
using IWS.Mvc;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;

namespace Comics.Web.Areas.Admin.Controllers
{
    public class PiecesController : DbController<Db>
	{
		public ActionResult Index(PiecesParams param)
		{
			param.Update(this);
			param.Load(Db);
			return View(Piece.Load(Db).ToModel(param));
		}

		public ActionResult Edit(int? id)
		{
			var param = Session["Pieces.Index"] as PiecesParams;
			var model = PieceModel.Create(Db, id, param?.PuzzleId);
			if (model == null)
				return HttpNotFound();

			return View(model);
		}

		[HttpPost]
		public ActionResult Edit(PieceModel model)
		{
			if (!ModelState.IsValid)
			{
				model.Load(Db);
				return View(model);
			}

			model.Update(Db);
			return RedirectToAction("Index");
		}

		public ActionResult Delete(int? id)
		{
			var item = id.HasValue ? Piece.Load(Db, id.Value) : null;
			if (item == null)
				return HttpNotFound();

			item.Delete(Db);
			Db.SaveChanges();
			return RedirectToAction("Index");
		}

		[HttpPost]
		public ActionResult Move(int id, int offset)
		{
			var item = Piece.Load(Db, id);
			if (item == null)
				return HttpNotFound();

			item.Move(Db, offset);
			Db.SaveChanges();
			return Json(true);
		}
	}
}