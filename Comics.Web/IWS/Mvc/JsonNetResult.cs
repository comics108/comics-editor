using IWS.Utils;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.Mvc;

namespace IWS.Mvc
{
	public class JsonNetResult : JsonResult
	{
		public JsonNetResult(object data = null, JsonRequestBehavior behavior = JsonRequestBehavior.AllowGet)
			: base()
		{
			Data = data;
			JsonRequestBehavior = behavior;
		}

		public override void ExecuteResult(ControllerContext context)
		{
			if (context == null)
				throw new ArgumentNullException("context");
			if (this.JsonRequestBehavior == JsonRequestBehavior.DenyGet && string.Equals(context.HttpContext.Request.HttpMethod, "GET", StringComparison.OrdinalIgnoreCase))
				throw new InvalidOperationException("JSON GET is not allowed");

			var response = context.HttpContext.Response;
			response.ContentType = !string.IsNullOrEmpty(ContentType) ? ContentType : "application/json";

			if (ContentEncoding != null)
				response.ContentEncoding = ContentEncoding;

			response.Write(Data.ToJson());
		}
	}
}
