using IWS.Utils;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using System.Web.Http.Filters;

namespace IWS.WebApi
{
	public class HandleErrorExAttribute : ExceptionFilterAttribute
	{
		public override void OnException(HttpActionExecutedContext context)
		{
			// temporary workaround for issue in Web Api with request cancelling
			// http://stackoverflow.com/questions/22157596/asp-net-web-api-operationcanceledexception-when-browser-cancels-the-request
			if (context.Exception != null && !(context.Exception is TaskCanceledException) && !(context.Exception is OperationCanceledException))
				Logger.Instance.Error("Unexpected error occurred.", context.Exception);
			context.Response = context.Request.CreateResponse(HttpStatusCode.InternalServerError, ApiResult.Exception);
		}
	}
}