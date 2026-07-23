using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Data;

namespace Comics.Editor.ViewModel
{
	public class ScrollConverter : IMultiValueConverter
	{
		private bool isFocusedOld = false;

		public object Convert(object[] values, Type targetType, object parameter, CultureInfo culture)
		{
			if (values == null || values.Length != 3 || !(values[0] is int) || !(values[1] is double) || !(values[2] is bool))
				return string.Empty;

			var value = (int)values[0];
			var scroll = (double)values[1];
			var isFocused = (bool)values[2];
			var result = (isFocused || isFocusedOld ? (int)scroll : value).ToString();
			isFocusedOld = isFocused;
			return result;
		}

		public object[] ConvertBack(object value, Type[] targetTypes, object parameter, CultureInfo culture)
		{
			throw new NotImplementedException();
		}
	}
}
