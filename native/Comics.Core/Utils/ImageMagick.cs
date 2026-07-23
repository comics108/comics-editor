using System;
using System.Diagnostics;
using System.Drawing;
using System.Web.Hosting;

namespace IWS.Utils
{
	public static class ImageMagick
	{
		private static readonly string Path = HostingEnvironment.MapPath("~/bin/Utils/ImageMagick/magick.exe");

		public static void ResizeImage(string srcPath, string dstPath, int dstWidth, int dstHeight)
		{
			RunProcess(Path, string.Format(@"""{0}"" -background none -resize {2}x{3}^ -gravity center -extent {2}x{3} ""{1}""", srcPath, dstPath, dstWidth, dstHeight));
		}

		public static void ScaleImage(string srcPath, string dstPath, int maxWidth, int maxHeight, int? quality = null)
		{
			var qualityString = quality.HasValue ? string.Format("-quality {0}%", quality.Value) : string.Empty;
			RunProcess(Path, string.Format(@"""{0}"" {4} -resize {2}x{3}> ""{1}""", srcPath, dstPath, maxWidth, maxHeight, qualityString));
		}

		public static Size GetImageSize(string srcPath)
		{
			var output = RunProcess(Path, string.Format(@"identify -format ""%[fx:w]x%[fx:h]"" ""{0}""", srcPath));
			var values = output.Split(new char[] { 'x' }, StringSplitOptions.RemoveEmptyEntries);
			if (values.Length != 2)
				return Size.Empty;
			return new Size(int.Parse(values[0]), int.Parse(values[1]));
		}

		public static void CreateTiles(string srcPath, string dstPathTempl, int tileWidth, int tileHeight)
		{
			dstPathTempl = string.Format(dstPathTempl, "%[filename:tile]");
			RunProcess(Path, string.Format(@"""{0}"" -crop {1}x{2} -set filename:tile ""%[fx:page.x/{1}]_%[fx:page.y/{2}]"" +repage +adjoin -strip ""{3}""", srcPath, tileWidth, tileHeight, dstPathTempl));
		}

		public static string RunProcess(string fileName, string arguments)
		{
			using (var proc = new Process())
			{
				proc.StartInfo.WindowStyle = ProcessWindowStyle.Hidden;
				proc.StartInfo.UseShellExecute = false;
				proc.StartInfo.RedirectStandardOutput = true;
				proc.StartInfo.FileName = fileName;
				proc.StartInfo.Arguments = arguments;
				proc.StartInfo.ErrorDialog = false;
				proc.StartInfo.CreateNoWindow = true;

				proc.Start();
				var output = proc.StandardOutput.ReadToEnd();
				proc.WaitForExit();
				return output;
			}
		}
	}
}