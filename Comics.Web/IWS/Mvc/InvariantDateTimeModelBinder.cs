using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Web;
using System.Web.Mvc;

namespace IWS.Mvc
{
	public class InvariantDateTimeModelBinder : DefaultModelBinder
	{
		public override object BindModel(ControllerContext controllerContext, ModelBindingContext bindingContext)
		{
			var value = bindingContext.ValueProvider.GetValue(bindingContext.ModelName);
			var format = bindingContext.ModelMetadata.DisplayFormatString?.Replace("{0:", string.Empty).Replace("}", string.Empty);
			DateTime result;
			if (value != null && DateTime.TryParseExact(value.AttemptedValue, format, CultureInfo.InvariantCulture, DateTimeStyles.None, out result))
				return result;

			return base.BindModel(controllerContext, bindingContext);
		}
	}
}