using System.Net;
using System.Net.Http;
using System.Web.Http.Controllers;
using System.Web.Http.Filters;

namespace IWS.WebApi
{
	public class CheckModelAttribute : ActionFilterAttribute
	{
		public override void OnActionExecuting(HttpActionContext actionContext)
		{
			// if request contains an empty or invalid model, then return the "bad request" error
			if (actionContext.ActionArguments.ContainsValue(null) || !actionContext.ModelState.IsValid)
				actionContext.Response = actionContext.Request.CreateResponse(HttpStatusCode.BadRequest, ApiResult.ErrorBadRequest);
		}
	}
}