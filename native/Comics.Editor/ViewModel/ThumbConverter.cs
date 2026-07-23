using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Data;

namespace Comics.Editor.ViewModel
{
	public class ThumbConverter : IMultiValueConverter
	{
		public object Convert(object[] values, Type targetType, object parameter, CultureInfo culture)
		{
			if (!(parameter is double))
				return 0d;

			if (values == null || values.Length != 2 || !(values[0] is double) || !(values[1] is double))
				return (double)parameter;
			
			return (double)values[1] / (double)values[0] * (double)parameter;
		}

		public object[] ConvertBack(object value, Type[] targetTypes, object parameter, CultureInfo culture)
		{
			throw new NotImplementedException();
		}
	}
}
