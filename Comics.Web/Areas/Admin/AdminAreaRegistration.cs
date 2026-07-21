using Comics.Web.Areas.Admin.Controllers;
using IWS.Mvc;
using System;
using System.Web.Mvc;
using System.Web.Optimization;

namespace Comics.Web.Areas.Admin
{
	public class AdminAreaRegistration : AreaRegistration
	{
		public override string AreaName
		{
			get
			{
				return "Admin";
			}
		}

		public override void RegisterArea(AreaRegistrationContext context)
		{
			BundleConfig.RegisterBundles(BundleTable.Bundles);
			GlobalFilters.Filters.Add(new AuthorizeExAttribute());
			ModelBinders.Binders.Add(typeof(DateTime), new InvariantDateTimeModelBinder());

			context.MapRoute(
				"Admin_Root",
				"admin/{action}",
				new { controller = "Admin", action = "Index" },
				new { isMethodInHomeController = new RootRouteConstraint<AdminController>() });

			context.MapRoute(
				"Admin_default",
				"admin/{controller}/{action}/{id}",
				new { action = "Index", id = UrlParameter.Optional }
			);

			context.Routes.LowercaseUrls = true;
		}
	}
}