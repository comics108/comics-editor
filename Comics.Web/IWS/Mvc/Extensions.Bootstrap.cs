using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.ComponentModel.DataAnnotations;
using System.IO;
using System.Linq;
using System.Linq.Expressions;
using System.Web;
using System.Web.Mvc;
using System.Web.Mvc.Html;
using System.Web.Routing;
using System.Web.UI;

namespace IWS.Mvc
{
    public static partial class Extensions
    {
		#region HtmlHelper extensions		        

		public static MvcHtmlString MenuItem(this HtmlHelper htmlHelper, string cssClass, string actionName, string controllerName, string displayText = null, string routeName = null, object routeValues = null, object htmlAttributes = null, bool ignoreAction = true, bool visible = true)
		{
			if (!visible)
				return MvcHtmlString.Empty;

			var iBuilder = new TagBuilder(HtmlTextWriterTag.I.ToString());
			iBuilder.AddCssClass("fa");
			if (!string.IsNullOrWhiteSpace(cssClass))
				iBuilder.AddCssClass(cssClass);

			var spanBuilder = new TagBuilder(HtmlTextWriterTag.Span.ToString());
			spanBuilder.InnerHtml = htmlHelper.Encode(displayText ?? controllerName);

			var actionLinkBuilder = new TagBuilder(HtmlTextWriterTag.A.ToString());

			var linkUrl = string.Empty;
			if (!string.IsNullOrWhiteSpace(routeName))
			{
				var urlHelper = new UrlHelper(htmlHelper.ViewContext.RequestContext, htmlHelper.RouteCollection);
				var routeUrl = urlHelper.HttpRouteUrl(routeName, routeValues);//urlHelper.RouteUrl(routeName, routeValues);
				if (routeUrl != null && routeUrl.IndexOf("?") != -1)
					routeUrl = routeUrl.Substring(0, routeUrl.IndexOf("?"));
				linkUrl = routeUrl;
			}
			if (string.IsNullOrWhiteSpace(linkUrl))
				linkUrl = UrlHelper.GenerateUrl(null, actionName, controllerName, routeValues != null ? new RouteValueDictionary(routeValues) : null, htmlHelper.RouteCollection, htmlHelper.ViewContext.RequestContext, true);

			actionLinkBuilder.Attributes.Add("href", linkUrl);
			actionLinkBuilder.InnerHtml = iBuilder.ToString() + " " + spanBuilder.ToString();

			var liBuilder = new TagBuilder(HtmlTextWriterTag.Li.ToString());
			liBuilder.InnerHtml = actionLinkBuilder.ToString(TagRenderMode.Normal);

			var attrs = new RouteValueDictionary(htmlAttributes);
			if (htmlHelper.IsCurrentAction(actionName, controllerName, ignoreAction))
			{
				liBuilder.AddCssClass(attrs.ContainsKey("class") ? attrs["class"] + " active" : "active");
				liBuilder.MergeAttributes(attrs);
			}
			else
				liBuilder.MergeAttributes(attrs);
			return new MvcHtmlString(liBuilder.ToString(TagRenderMode.Normal));
		}

		/// <summary>
		/// Checks the ModelState for an error, and returns the given error string if there is one, or null if there is no error
		/// Used to set class="error" on elements to present the error to the user
		/// </summary>		
		/// <returns>Error class</returns>
		public static MvcHtmlString ErrorClassFor<TModel, TProperty>(this HtmlHelper<TModel> htmlHelper, Expression<Func<TModel, TProperty>> expression, string errorClass = "has-error")
		{
			var modelName = htmlHelper.ViewContext.ViewData.TemplateInfo.GetFullHtmlFieldName(ExpressionHelper.GetExpressionText(expression));
			return htmlHelper.ViewData.ModelState[modelName]?.Errors.Count > 0 ? new MvcHtmlString(errorClass) : null;
		}

		public static MvcHtmlString FormGroupFor<TModel, TProperty>(this HtmlHelper<TModel> htmlHelper, Expression<Func<TModel, TProperty>> expression, object htmlAttributes = null, string groupCssClass = null)
		{
			return htmlHelper.FormGroupFor(expression, null, htmlAttributes, groupCssClass);
		}

		public static MvcHtmlString FormGroupFor<TModel, TProperty>(this HtmlHelper<TModel> htmlHelper, Expression<Func<TModel, TProperty>> expression, SelectList selectList, object htmlAttributes = null, string groupCssClass = null)
		{
			var attrs = htmlHelper.ObjectToHtmlAttributes(htmlAttributes);
			if (attrs.ContainsKey("class"))
				attrs["class"] += " form-control";
			else
				attrs.Add("class", "form-control");

			var metadata = ModelMetadata.FromLambdaExpression(expression, htmlHelper.ViewData);
			// Check property name to null and allow custom prop names, i.e. instead of @Html.FormGroupFor(x => x.Item.CityId) allow @Html.FormGroupFor(x => cityId).
			// For this example getting real property name can be as: (expression.Body as MemberExpression).Member.Name and will contains "cityId".
			var prop = metadata.PropertyName == null ? null : metadata.ContainerType.GetProperty(metadata.PropertyName);
			var disabled = prop == null ? false : prop.GetCustomAttributes(typeof(KeyAttribute), true).Any() || prop.GetCustomAttributes(typeof(EditableAttribute), true).OfType<EditableAttribute>().FirstOrDefault()?.AllowEdit == false;
			if (disabled)
				attrs["disabled"] = "disabled";

			var group = new TagBuilder(HtmlTextWriterTag.Div.ToString());
			group.AddCssClass("form-group");
			if (!string.IsNullOrEmpty(groupCssClass))
				group.AddCssClass(groupCssClass);
			var errorClass = htmlHelper.ErrorClassFor(expression)?.ToString();
			if (!string.IsNullOrEmpty(errorClass))
				group.AddCssClass(errorClass);
			group.InnerHtml = htmlHelper.LabelFor(expression, new { @class = "col-sm-2 control-label" }).ToString();

			var div = new TagBuilder(HtmlTextWriterTag.Div.ToString());
			div.AddCssClass("col-sm-10");
			if (selectList == null)
				div.InnerHtml = htmlHelper.EditorFor(expression, new { htmlAttributes = attrs }).ToString();
			else
				div.InnerHtml = htmlHelper.DropDownListFor(expression, selectList, attrs).ToString();
			if (disabled)
				div.InnerHtml += htmlHelper.HiddenFor(expression);
			div.InnerHtml += htmlHelper.ValidationMessageFor(expression)?.ToString();
			group.InnerHtml += div.ToString();
			return new MvcHtmlString(group.ToString());
		}

		public static MvcHtmlString FormGroupFor<TModel>(this HtmlHelper<TModel> htmlHelper, Expression<Func<TModel, bool>> expression, object htmlAttributes = null, string groupCssClass = null)
		{
			var group = new TagBuilder(HtmlTextWriterTag.Div.ToString());
			group.AddCssClass("form-group");
			if (!string.IsNullOrEmpty(groupCssClass))
				group.AddCssClass(groupCssClass);
			var errorClass = htmlHelper.ErrorClassFor(expression)?.ToString();
			if (!string.IsNullOrEmpty(errorClass))
				group.AddCssClass(errorClass);

			var div = new TagBuilder(HtmlTextWriterTag.Div.ToString());
			div.AddCssClass("col-sm-offset-2 col-sm-10");

			var checkbox = new TagBuilder(HtmlTextWriterTag.Div.ToString());
			checkbox.AddCssClass("checkbox");

			var label = new TagBuilder(HtmlTextWriterTag.Label.ToString());
			label.InnerHtml = htmlHelper.CheckBoxFor(expression, htmlAttributes).ToString();
			label.InnerHtml += htmlHelper.DisplayNameFor(expression).ToString();
			checkbox.InnerHtml = label.ToString();

			div.InnerHtml = checkbox.ToString();
			div.InnerHtml += htmlHelper.ValidationMessageFor(expression)?.ToString();
			group.InnerHtml = div.ToString();
			return new MvcHtmlString(group.ToString());
		}

		#endregion
	}
}