using IWS.Utils;
using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using System.Web;
using System.Web.Hosting;

namespace IWS.Utils
{
	public static class ImageManager
	{
		public const string FolderImages = "/Images/";
		public const string FolderFiles = "/Files/";
		public const string SizePattern = "*";

		public static string TempFolderPath { get; private set; }

		private static string GetFileExt(string name)
		{
			var ext = Path.GetExtension(name);
			return !string.IsNullOrEmpty(ext) ? ext : ".jpg";
		}

		private static string GetUrlExt(string url)
		{
			var ext = new FileInfo(new Uri(url).AbsolutePath).Extension;
			return !string.IsNullOrEmpty(ext) ? ext : ".jpg";
		}

		private static string GetFileUrl(string ext, string folder = FolderImages)
		{
			var folderPath = HostingEnvironment.MapPath(folder);
			if (!Directory.Exists(folderPath))
				Directory.CreateDirectory(folderPath);

			return folder + Guid.NewGuid().ToString("N") + ext;
		}

		public static string Update(string oldUrl, HttpPostedFileBase file, string folder = FolderImages, params Size[] sizes)
		{
			if (file == null || file.ContentLength == 0)
				return oldUrl;

			try
			{
				var url = GetFileUrl(GetFileExt(file.FileName), folder);
				file.SaveAs(HostingEnvironment.MapPath(url));
				url = ResizeImage(url, sizes);
				Delete(oldUrl);
				return url;
			}
			catch
			{
				return oldUrl;
			}
		}

		public static string Update(string oldUrl, string remoteUrl, string folder = FolderImages, params Size[] sizes)
		{
			if (string.IsNullOrEmpty(remoteUrl))
				return oldUrl;

			try
			{
				var url = GetFileUrl(GetUrlExt(remoteUrl), folder);
				using (var client = new WebClient())
					client.DownloadFile(remoteUrl, HostingEnvironment.MapPath(url));
				url = ResizeImage(url, sizes);
				Delete(oldUrl);
				return url;
			}
			catch
			{
				return oldUrl;
			}
		}

		public static string Update(string oldUrl, string name, string tempPath, string folder = FolderImages, params Size[] sizes)
		{
			if (string.IsNullOrEmpty(name) || string.IsNullOrEmpty(tempPath) || !File.Exists(tempPath))
				return oldUrl;

			try
			{
				var url = GetFileUrl(GetFileExt(name), folder);
				File.Copy(tempPath, HostingEnvironment.MapPath(url));
				url = ResizeImage(url, sizes);
				Delete(oldUrl);
				return url;
			}
			catch
			{
				return oldUrl;
			}
		}

		public static string ResizeImage(string url, Size[] sizes)
		{
			if (sizes == null || !sizes.Any())
				return url;

			var path = HostingEnvironment.MapPath(url);
			var ext = GetFileExt(path);
			foreach (var size in sizes)
				ImageMagick.ResizeImage(path, path.Replace(ext, size.Width + ext), size.Width, size.Height);
			return url.Replace(ext, SizePattern + ext);
		}

		public static void DeleteFolder(string folder)
		{
			var path = !string.IsNullOrEmpty(folder) ? HostingEnvironment.MapPath(folder) : null;
			if (!string.IsNullOrEmpty(path) && Directory.Exists(path))
				Directory.Delete(path, true);
		}

		public static void Delete(string url)
		{
			var path = !string.IsNullOrEmpty(url) ? HostingEnvironment.MapPath(url.Replace(SizePattern, string.Empty)) : null;
			if (string.IsNullOrEmpty(path))
				return;

			if (url.Contains(SizePattern))
			{
				var info = new FileInfo(path);
				foreach (var file in info.Directory.EnumerateFiles(info.Name.Replace(info.Extension, "*" + info.Extension)))
					file.Delete();
			}
			else if (File.Exists(path))
				File.Delete(path);
		}

		public static void InitTempFolder()
		{
			TempFolderPath = HostingEnvironment.MapPath("~/Images/Temp");
			if (!Directory.Exists(TempFolderPath))
				Directory.CreateDirectory(TempFolderPath);
		}
	}
}
