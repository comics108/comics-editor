using Comics.Editor.Models;
using Comics.Editor.Utils;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace Comics.Editor.ViewModel
{
	public class ImagePathConverter : IValueConverter
	{
		private const int TileScale = 2;

		#region IValueConverter Members

		public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
		{
			var image = value as Image;
			var folder = parameter as string;
			if (image == null || string.IsNullOrEmpty(image.File) || string.IsNullOrEmpty(folder))
				return null;

			return image.IsTiles ? TileImage(folder, image) : SingleImage(Path.Combine(FileManager.TempFolder, folder, image.File));
		}

		private ImageSource SingleImage(string path)
		{
			BitmapImage image = new BitmapImage();
			image.BeginInit();
			image.CacheOption = BitmapCacheOption.OnLoad;
			image.UriSource = new Uri(path);
			image.EndInit();
			return image;
		}

		private ImageSource TileImage(string folder, Image image)
		{
			folder = Path.Combine(FileManager.TempFolder, folder);
			var fileName = string.Format(image.File, (int)(FileManager.PuzzleScales[0] * 1000), "*", "*");
			var visual = new DrawingVisual();
			using (var context = visual.RenderOpen())
			{
				foreach (var file in Directory.GetFiles(folder, fileName))
				{
					var parts = Path.GetFileNameWithoutExtension(file).Split('_');
					int col, row;
					if (parts.Length < 4 || !int.TryParse(parts[parts.Length - 2], out col) || !int.TryParse(parts[parts.Length - 1], out row))
						continue;

					var x = col * FileManager.TileSize;
					var y = row * FileManager.TileSize;
					var width = Math.Min(image.Width - x, FileManager.TileSize);
					var height = Math.Min(image.Height - y, FileManager.TileSize);
					if (width > 0 && height > 0)
						context.DrawImage(SingleImage(file), new Rect(x, y, width, height));
				}
			}
			var bmp = new RenderTargetBitmap(image.Width / TileScale, image.Height / TileScale, 96 / TileScale, 96 / TileScale, PixelFormats.Pbgra32);
			bmp.Render(visual);

			var png = new PngBitmapEncoder();
			png.Frames.Add(BitmapFrame.Create(bmp));
			var stream = new MemoryStream();
			png.Save(stream);

			var result = new BitmapImage();
			result.BeginInit();
			result.CacheOption = BitmapCacheOption.OnLoad;
			result.StreamSource = stream;
			result.EndInit();
			return result;
		}

		public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
		{
			throw new NotImplementedException();
		}

		#endregion
	}
}
