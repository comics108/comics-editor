using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Optimization;

namespace Comics.Web.Areas.Admin
{
	public static class BundleConfig
	{
		private static readonly string[] CssCommon = new string[]
		{
			"~/Content/fontawesome/font-awesome.css",
			"~/Content/bootstrap/bootstrap.css", "~/Content/bootstrap/bootstrap-theme.css",
			"~/Content/AdminLTE/AdminLTE.css", "~/Content/AdminLTE/skins/skin-purple.css"
		};

		private static readonly string[] JsCommon = new string[]
		{
			"~/Scripts/jquery-{version}.js",
			"~/Scripts/bootstrap/bootstrap.js",
			"~/Scripts/AdminLTE/app.js"
		};

		public static void RegisterBundles(BundleCollection bundles)
		{
			bundles.Add(LessBundle("~/bundles/css-admin", "~/Content/admin.less"));

			bundles.Add(JsBundle("~/bundles/js-admin"));
			bundles.Add(JsBundle("~/bundles/js-sortable", "~/Scripts/jquery-ui-{version}.js", "~/Scripts/sortable.js"));
		}

		private static Bundle LessBundle(string name, params string[] paths)
		{
			var allPaths = new List<string>(CssCommon);
			allPaths.AddRange(paths);
			return new LessBundle(name).Include(allPaths.ToArray());
		}

		private static Bundle JsBundle(string name, params string[] paths)
		{
			var allPaths = new List<string>(JsCommon);
			allPaths.AddRange(paths);
			return new ScriptBundle(name).Include(allPaths.ToArray());
		}
	}
}