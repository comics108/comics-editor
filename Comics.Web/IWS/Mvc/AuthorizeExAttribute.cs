using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Web;
using System.Web.Mvc;

namespace IWS.Mvc
{
	public class AuthorizeExAttribute : AuthorizeAttribute
	{
		protected override void HandleUnauthorizedRequest(AuthorizationContext filterContext)
		{
			if (!filterContext.HttpContext.Request.IsAjaxRequest())
			{
				base.HandleUnauthorizedRequest(filterContext);
				return;
			}

			filterContext.Result = new HttpStatusCodeResult(HttpStatusCode.Unauthorized);
			filterContext.HttpContext.Response.TrySkipIisCustomErrors = true;
			filterContext.HttpContext.Response.SuppressFormsAuthenticationRedirect = true;
		}
	}
}