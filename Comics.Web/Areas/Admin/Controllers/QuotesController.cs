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
    public class QuotesController : DbController<Db>
	{
		public ActionResult Index(QuotesParams param)
		{
			param.Update(this);
			return View(Quote.Load(Db).ToModel(param));
		}

		public ActionResult Edit(int? id)
		{
			var model = QuoteModel.Create(Db, id);
			if (model == null)
				return HttpNotFound();

			return View(model);
		}

		[HttpPost]
		public ActionResult Edit(QuoteModel model)
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
			var item = id.HasValue ? Quote.Load(Db, id.Value) : null;
			if (item == null)
				return HttpNotFound();

			item.Delete(Db);
			Db.SaveChanges();
			return RedirectToAction("Index");
		}
	}
}