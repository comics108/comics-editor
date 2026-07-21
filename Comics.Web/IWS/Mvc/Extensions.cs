using IWS.Utils;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Web.Mvc;
using System.Web.Mvc.Html;
using System.Web.Routing;

namespace IWS.Mvc
{
	public static partial class Extensions
	{
		public static MvcTag BeginTag(this HtmlHelper htmlHelper, string tagName, object htmlAttributes)
		{
			return htmlHelper.BeginTag(tagName, htmlHelper.ObjectToHtmlAttributes(htmlAttributes));
		}

		public static MvcTag BeginTag(this HtmlHelper htmlHelper, string tagName, IDictionary<string, object> htmlAttributes)
		{
			TagBuilder tagBuilder = new TagBuilder(tagName);
			tagBuilder.MergeAttributes(htmlAttributes);
			htmlHelper.ViewContext.Writer.Write(tagBuilder.ToString(TagRenderMode.StartTag));
			return new MvcTag(htmlHelper.ViewContext, tagName);
		}

		public static MvcTag BeginActionLink(this HtmlHelper htmlHelper, string actionName, string controllerName, object routeValues = null, object htmlAttributes = null)
		{
			return htmlHelper.BeginActionLink(actionName, controllerName, new RouteValueDictionary(routeValues), htmlHelper.ObjectToHtmlAttributes(htmlAttributes));
		}

		public static MvcTag BeginActionLink(this HtmlHelper htmlHelper, string actionName, string controllerName, RouteValueDictionary routeValues, IDictionary<string, object> htmlAttributes)
		{
			var hrefUrl = UrlHelper.GenerateUrl(null, actionName, controllerName, routeValues, htmlHelper.RouteCollection, htmlHelper.ViewContext.RequestContext, true);
			htmlAttributes.Add("href", hrefUrl);
			return BeginTag(htmlHelper, "a", htmlAttributes);
		}

		private static bool IsCurrentAction(this HtmlHelper htmlHelper, string actionName, string controllerName, bool ignoreAction = false)
		{
			var currentAction = htmlHelper.ViewContext.RouteData.GetRequiredString("action");
			var currentController = htmlHelper.ViewContext.RouteData.GetRequiredString("controller");
			return (ignoreAction || actionName.Equals(currentAction, StringComparison.InvariantCultureIgnoreCase)) &&
				controllerName.Equals(currentController, StringComparison.InvariantCultureIgnoreCase);
		}

		public static MvcHtmlString MenuLink(this HtmlHelper htmlHelper, string linkText, string actionName, string controllerName, bool ignoreAction = false, object routeValues = null)
		{
			if (htmlHelper.IsCurrentAction(actionName, controllerName, ignoreAction))
				return htmlHelper.ActionLink(linkText, actionName, controllerName, routeValues, new { @class = "selected" });

			return htmlHelper.ActionLink(linkText, actionName, controllerName);
		}

		public static MvcTag BeginMenuLink(this HtmlHelper htmlHelper, string actionName, string controllerName, bool ignoreAction = false, object routeValues = null)
		{
			if (htmlHelper.IsCurrentAction(actionName, controllerName, ignoreAction))
				return htmlHelper.BeginActionLink(actionName, controllerName, routeValues, new { @class = "selected" });

			return htmlHelper.BeginActionLink(actionName, controllerName, routeValues, null);
		}

		public static string ViewToString(this Controller controller, string viewName, object model)
		{
			controller.ViewData.Model = model;
			using (var sw = new StringWriter())
			{
				var viewResult = ViewEngines.Engines.FindPartialView(controller.ControllerContext, viewName);
				var viewContext = new ViewContext(controller.ControllerContext, viewResult.View, controller.ViewData, controller.TempData, sw);
				viewResult.View.Render(viewContext, sw);
				viewResult.ViewEngine.ReleaseView(controller.ControllerContext, viewResult.View);
				return sw.GetStringBuilder().ToString();
			}
		}

		public static SelectList ToSelectList(this Enum value, string optionalLabel = null, string optionalValue = null)
		{
			var result = new SelectList(Enum.GetValues(value.GetType()).OfType<Enum>().Select(x => new { Text = x.GetEnumName(), Value = x }), "Value", "Text");
			if (string.IsNullOrEmpty(optionalLabel))
				return result;

			var list = result.ToList();
			list.Insert(0, new SelectListItem { Text = optionalLabel, Value = optionalValue });
			return new SelectList(list, "Value", "Text");
		}

		public static SelectList ToSelectList<T>(this IEnumerable<T> items, string textField = "Name", string valueField = "Id", string optionalLabel = null, string optionalValue = null)
		{
			var result = new SelectList(items, valueField, textField);
			if (string.IsNullOrEmpty(optionalLabel))
				return result;

			var list = result.ToList();
			list.Insert(0, new SelectListItem { Text = optionalLabel, Value = optionalValue });
			return new SelectList(list, "Value", "Text");
		}

		public static IDictionary<string, object> ObjectToHtmlAttributes(this HtmlHelper htmlHelper, object htmlAttributes)
		{
			return htmlAttributes as IDictionary<string, object> ?? HtmlHelper.AnonymousObjectToHtmlAttributes(htmlAttributes);
		}
	}
}