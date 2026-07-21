using Comics.DAL;
using Comics.DAL.Migrations;
using IWS.Utils;
using System;
using System.Collections.Generic;
using System.Data.Entity;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using System.Web.Security;
using System.Web.SessionState;

namespace Comics.Web
{
	public class Global : HttpApplication
	{
		protected void Application_Start(object sender, EventArgs e)
		{
			AreaRegistration.RegisterAllAreas();
			ImageManager.InitTempFolder();

			if (WebConfig.MigrationEnabled)
				Database.SetInitializer(new MigrateDatabaseToLatestVersion<Db, DbConfig>());

			//var certPath = Server.MapPath(string.Format("~/App_Data/{0}.p12", WebConfig.IsApnProduction ? WebConfig.ApnProdCert : WebConfig.ApnDevCert));
			var certPath = Server.MapPath(string.Format("~/App_Data/{0}.p12", WebConfig.ApnProdCert));
			PushManager.RegisterApns(WebConfig.IsApnProduction, certPath);
			PushManager.RegisterFcm(WebConfig.FcmApiKey);
		}

		protected void Application_End(object sender, EventArgs e)
		{
			PushManager.Stop();
		}
	}
}