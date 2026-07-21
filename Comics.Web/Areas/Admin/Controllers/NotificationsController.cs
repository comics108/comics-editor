using Comics.DAL;
using Comics.Web.Areas.Admin.Models;
using IWS.Mvc;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;

namespace Comics.Web.Areas.Admin.Controllers
{
    public class NotificationsController : DbController<Db>
	{
        public ActionResult Index()
        {
			var model = NotificationModel.Create();
			if (model == null)
				return HttpNotFound();

			return View(model);
		}

		[HttpPost]
		public ActionResult Index(NotificationModel model)
		{
			if (!ModelState.IsValid)
			{
				model.Load(Db);
				return View(model);
			}

			model.Update(Db);
			return RedirectToAction("Index");
		}
	}
}