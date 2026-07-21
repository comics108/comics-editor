using Comics.DAL;
using IWS.WebApi;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Http.Controllers;

namespace Comics.Web.Areas.Api
{
	public class TokenAuthorizeAttribute : AuthorizeExAttribute
	{
		private const string Scheme = "Mahabharata";

		public bool UserRequired { get; set; }

		protected override bool IsAuthorized(HttpActionContext actionContext)
		{
			var controller = actionContext.ControllerContext.Controller as DbController<Db>;
			if (controller == null)
				return false;

			var token = GetToken(actionContext);
			return token != Guid.Empty && controller.Db.Devices.Any(x => x.Id == token) && (!UserRequired || base.IsAuthorized(actionContext));
		}

		public static Guid GetToken(HttpActionContext actionContext)
		{
			var auth = actionContext.Request.Headers.Authorization;
			Guid token;
			if (auth != null && auth.Scheme == Scheme && Guid.TryParse(auth.Parameter, out token))
				return token;
			return Guid.Empty;
		}
	}
}