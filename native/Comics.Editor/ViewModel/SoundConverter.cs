using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Data;

namespace Comics.Editor.ViewModel
{
	public class SoundConverter : IMultiValueConverter
	{
		public object Convert(object[] values, Type targetType, object parameter, CultureInfo culture)
		{
			if (values == null || values.Length < 2)
				return 0d;

			var scale = GetValue(values[values.Length - 1], 1) * GetValue(parameter, 1);
			var value = GetValue(values[values.Length - 2], 0);
			if (values.Length == 3)
				value -= GetValue(values[0], 0);

			return value * scale;
		}

		public object[] ConvertBack(object value, Type[] targetTypes, object parameter, CultureInfo culture)
		{
			throw new NotImplementedException();
		}

		private static double GetValue(object obj, double defValue)
		{
			if (obj == null || obj == DependencyProperty.UnsetValue)
				return defValue;

			return System.Convert.ToDouble(obj);
		}
	}
}
