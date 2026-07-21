using PagedList;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Dynamic;
using System.Web;
using System.Web.Mvc;
using System.Web.Routing;
using System.Web.UI;

namespace IWS.Mvc
{
	public class ListParams
	{
		public virtual string DefaultSort
		{
			get { return "Id"; }
		}

		public virtual bool DefaultAsc
		{
			get { return true; }
		}

		public virtual int DefaultSize
		{
			get { return 50; }
		}

		public string Sort { get; set; }
		public bool? Asc { get; set; }
		public int? Page { get; set; }
		public int? Size { get; set; }

		protected virtual void Update(ListParams savedParams, bool post)
		{
			if (string.IsNullOrEmpty(Sort))
				Sort = savedParams?.Sort ?? DefaultSort;
			if (!Asc.HasValue)
				Asc = savedParams?.Asc ?? DefaultAsc;
			if (!Page.HasValue)
				Page = (!post ? savedParams?.Page : null) ?? 1;
			if (!Size.HasValue)
				Size = savedParams?.Size ?? DefaultSize;
		}

		public void Update(Controller controller)
		{
			var key = controller.RouteData.Values["controller"] + "." + controller.RouteData.Values["action"];
			var savedParams = controller.Session[key] as ListParams;
			Update(savedParams, controller.Request.HttpMethod == "POST");
			controller.Session[key] = this;
		}

		public virtual IQueryable<T> Filter<T>(IQueryable<T> query)
			where T : class
		{
			return query;
		}

		public virtual IQueryable<TResult> Select<TItem, TResult>(IQueryable<TItem> query)
			where TItem : class
			where TResult : class
		{
			return (IQueryable<TResult>)query;
		}

		public virtual string OrderBy()
		{
			var result = Sort;
			if (!Asc.Value)
				result += " desc";
			if (Sort != DefaultSort)
			{
				result += ", " + DefaultSort;
				if (!DefaultAsc)
					result += " desc";
			}
			return result;
		}
	}

	public class ListModel<TParams, TItem>
		where TParams : ListParams
		where TItem : class
	{
		public TParams Param { get; set; }
		public IPagedList<TItem> Items { get; set; }

		public static ListModel<TParams, TItem> Create<T>(TParams param, IQueryable<T> items)
			where T : class
		{
			items = param.Filter(items);
			var result = param.Select<T, TItem>(items);
			try
			{
				var orderBy = param.OrderBy();
				if (!string.IsNullOrWhiteSpace(orderBy))
					result = result.OrderBy(orderBy);
			}
			catch
			{
				result = result.OrderBy(param.DefaultSort);
			}
			return new ListModel<TParams, TItem>
			{
				Param = param,
				Items = result.ToPagedList(param.Page.Value, param.Size.Value)
			};
		}
	}

	public static partial class Extensions
	{
		public static ListModel<TParams, TItem> ToModel<TParams, TItem>(this IQueryable<TItem> items, TParams param)
			where TParams : ListParams
			where TItem : class
		{
			return ListModel<TParams, TItem>.Create(param, items);
		}

		public static ListModel<TParams, TItem> ToModel<TParams, TItem, T>(this IQueryable<T> items, TParams param)
			where TParams : ListParams
			where TItem : class
			where T : class
		{
			return ListModel<TParams, TItem>.Create(param, items);
		}

		public static MvcHtmlString OrderedTableHeader(this HtmlHelper htmlHelper, ListParams param, string column, object routeValues = null, string displayText = null)
		{
			var routeDic = new RouteValueDictionary(routeValues);
			routeDic.Add("sort", column.ToLower());

			var spanBuilder = new TagBuilder(HtmlTextWriterTag.Span.ToString());
			if (!string.Equals(param.Sort, column, StringComparison.InvariantCultureIgnoreCase))
			{
				spanBuilder.AddCssClass("glyphicon glyphicon-sort");
				routeDic.Add("asc", "true");
			}
			else if (param.Asc == true)
			{
				spanBuilder.AddCssClass("glyphicon glyphicon-sort-by-alphabet");
				routeDic.Add("asc", "false");
			}
			else
			{
				spanBuilder.AddCssClass("glyphicon glyphicon-sort-by-alphabet-alt");
				routeDic.Add("asc", "true");
			}
			spanBuilder.Attributes.Add("aria-hidden", "true");

			if (!string.IsNullOrWhiteSpace(column))
			{
				var action = htmlHelper.ViewContext.RouteData.GetRequiredString("action");
				var controller = htmlHelper.ViewContext.RouteData.GetRequiredString("controller");
				var actionUrl = UrlHelper.GenerateUrl(null, action, controller, routeDic, htmlHelper.RouteCollection, htmlHelper.ViewContext.RequestContext, true);
				var linkBuilder = new TagBuilder(HtmlTextWriterTag.A.ToString());
				linkBuilder.AddCssClass("text-nowrap");
				linkBuilder.Attributes.Add("href", actionUrl);
				linkBuilder.InnerHtml = spanBuilder.ToString(TagRenderMode.Normal) + $@"&nbsp;{htmlHelper.Encode(string.IsNullOrWhiteSpace(displayText) ? column : displayText)}";
				return MvcHtmlString.Create(linkBuilder.ToString(TagRenderMode.Normal));
			}
			else
			{
				return MvcHtmlString.Create(htmlHelper.Encode(displayText ?? ""));
			}
		}
	}
}