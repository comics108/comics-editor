using IWS.Utils;
using IWS.WebApi;
using System.Net.Http.Formatting;
using System.Web.Http;
using System.Web.Mvc;

namespace Comics.Web.Areas.Api
{
	public class ApiAreaRegistration : AreaRegistration
	{
		public override string AreaName
		{
			get
			{
				return "Api";
			}
		}

		public override void RegisterArea(AreaRegistrationContext context)
		{
			GlobalConfiguration.Configure(Register);
			AutoMapperConfig.Configure();
		}

		public static void Register(HttpConfiguration config)
		{
			config.Formatters.Clear();
			config.Formatters.Add(new JsonMediaTypeFormatter());
			config.Formatters.JsonFormatter.SerializerSettings = Extensions.SerializerSettings;

			config.Filters.Add(new HandleErrorExAttribute());
			config.Filters.Add(new CheckModelAttribute());

			config.Routes.MapHttpRoute(
				"Api_default",
				"api/{controller}/{action}"
			);
		}
	}
}