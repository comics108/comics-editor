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
    public class SeasonsController : DbController<Db>
	{
		public ActionResult Index(ListParams param)
		{
			param.Update(this);
			param.Sort = "Order";
			return View(Season.Load(Db).ToModel(param));
		}

		public ActionResult Edit(int? id)
		{
			var model = SeasonModel.Create(Db, id);
			if (model == null)
				return HttpNotFound();

			return View(model);
		}

		[HttpPost]
		public ActionResult Edit(SeasonModel model)
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
			var item = id.HasValue ? Season.Load(Db, id.Value) : null;
			if (item == null)
				return HttpNotFound();

			item.Delete(Db);
			Db.SaveChanges();
			return RedirectToAction("Index");
		}

		[HttpPost]
		public ActionResult Move(int id, int offset)
		{
			var item = Season.Load(Db, id);
			if (item == null)
				return HttpNotFound();

			item.Move(Db, offset);
			Db.SaveChanges();
			return Json(true);
		}
	}
}