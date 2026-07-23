using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Data;

namespace Comics.Editor.ViewModel
{
	public class PivotConverter : IMultiValueConverter
	{
		public object Convert(object[] values, Type targetType, object parameter, CultureInfo culture)
		{
			if (values == null || values.Length != 3 || !(values[0] is double) || !(values[1] is double) || !(values[2] is double))
				return 0d;

			return (double)values[0] * (double)values[1] - (double)values[2] / 2;
		}

		public object[] ConvertBack(object value, Type[] targetTypes, object parameter, CultureInfo culture)
		{
			throw new NotImplementedException();
		}
	}
}
