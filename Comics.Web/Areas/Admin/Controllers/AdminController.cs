using Comics.DAL;
using Comics.Web.Areas.Admin.Models;
using IWS.Mvc;
using IWS.Utils;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using System.Web.Security;

namespace Comics.Web.Areas.Admin.Controllers
{
	public class AdminController : DbController<Db>
	{
		[AllowAnonymous]
		public ActionResult Login()
		{
			if (Request.IsAuthenticated)
				return RedirectToAction("Index", "Admin");
			return View();
		}

		[AllowAnonymous]
		[HttpPost]
		public ActionResult Login(LoginModel model, string returnUrl)
		{
			if (!ModelState.IsValid)
				return View(model);

			if (model.Login == WebConfig.AdminUser && model.Password == WebConfig.AdminPassword)
			{
				FormsAuthentication.SetAuthCookie(model.Login, false, "/admin");
				if (!string.IsNullOrEmpty(returnUrl))
					return Redirect(returnUrl);
				return RedirectToAction("Index", "Admin");
			}

			ModelState.AddModelError(string.Empty, "Invalid username or password.");
			return View(model);
		}

		public ActionResult Logout()
		{
			FormsAuthentication.SignOut();
			return RedirectToAction("Login", "Admin");
		}

		public ActionResult Index()
		{
			return View();
		}

		public ActionResult Editor()
		{
			var path = Server.MapPath("~/Editor");
			var files = Directory.GetFiles(path);
			if (!files.Any())
				return HttpNotFound();

			var file = files.Last();
			return File(file, "application/zip", Path.GetFileName(file));
		}
	}
}