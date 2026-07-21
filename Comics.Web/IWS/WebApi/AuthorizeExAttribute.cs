using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web;
using System.Web.Http;
using System.Web.Http.Controllers;

namespace IWS.WebApi
{
	public class AuthorizeExAttribute : AuthorizeAttribute
	{
		protected override void HandleUnauthorizedRequest(HttpActionContext context)
		{
			context.Response = context.Request.CreateResponse(HttpStatusCode.Unauthorized, ApiResult.ErrorNeedToLogin);
		}
	}
}