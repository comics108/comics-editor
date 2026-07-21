using IWS.Utils;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web;
using System.Web.Http.Controllers;
using System.Web.Http.Filters;

namespace IWS.WebApi
{
	public class IpFilterAttribute : ActionFilterAttribute
	{
		private readonly string[] _allowedIps;

		public IpFilterAttribute()
			: this(WebConfig.AllowedIps)
		{
		}

		public IpFilterAttribute(string allowedIps)
		{
			_allowedIps = !string.IsNullOrEmpty(allowedIps) ? allowedIps.Split(';') : null;
		}

		public override void OnActionExecuting(HttpActionContext actionExecutedContext)
		{
			base.OnActionExecuting(actionExecutedContext);

			var actionContext = actionExecutedContext.Request.Properties["MS_HttpContext"] as HttpContextBase;
			if (actionContext == null || _allowedIps == null)
				return;

			var userIp = actionContext.Request.UserHostAddress;
			if (_allowedIps.Contains(userIp))
				return;

			actionExecutedContext.Response = actionExecutedContext.Request.CreateResponse(HttpStatusCode.Forbidden,
				string.Format("{0} is not in an allowed IP's list", userIp));
		}
	}
}