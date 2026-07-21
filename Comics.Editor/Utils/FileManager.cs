using IWS.Utils;
using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Comics.Editor.Utils
{
	public static class FileManager
	{
		public static readonly string TempFolder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Comics Editor\Temp");

		public const string FolderLayers = "layers";
		public const string FolderSounds = "sounds";

		public const int TileSize = 512;
		public const int PlaceholderSize = 512;
		public static readonly float[] ComicsScales = { 1.0f };
		public static readonly float[] PuzzleScales = { 1.0f, 0.5f, 0.25f, 0.125f };

		private static string GetFileExt(string name)
		{
			var ext = Path.GetExtension(name);
			return !string.IsNullOrEmpty(ext) ? ext : ".jpg";
		}

		public static bool CheckFile(string folder, string oldFile, string newFile)
		{
			var name = Path.GetFileNameWithoutExtension(newFile);
			var ext = GetFileExt(newFile);
			var singleName = name + ext;
			var tileName = name + "_{0}_{1}_{2}" + ext;
			return oldFile == singleName || oldFile == tileName || !File.Exists(Path.Combine(TempFolder, folder, singleName)) &&
				!Directory.GetFiles(Path.Combine(TempFolder, folder), string.Format(tileName, "*", "*", "*")).Any();
		}

		public static string Update(string folder, string oldFile, string newFile)
		{
			Delete(folder, oldFile);
			var name = Path.GetFileNameWithoutExtension(newFile) + GetFileExt(newFile);
			File.Copy(newFile, Path.Combine(TempFolder, folder, name));
			return name;
		}

		public static void Delete(string folder, string oldFile)
		{
			var path = !string.IsNullOrEmpty(oldFile) ? Path.Combine(TempFolder, folder, oldFile) : null;
			if (!string.IsNullOrEmpty(path) && File.Exists(path))
				File.Delete(path);
		}

		public static string UpdateTiles(string folder, string oldFile, string newFile, bool puzzle, out Size size)
		{
			DeleteTiles(folder, oldFile);

			folder = Path.Combine(TempFolder, folder);
			var name = Path.GetFileNameWithoutExtension(newFile);
			var ext = GetFileExt(newFile);
			size = ImageMagick.GetImageSize(newFile);
			var scales = puzzle ? PuzzleScales : ComicsScales;
			foreach (var tileScale in scales)
			{
				var scaleInt = (int)(tileScale * 1000);
				var src = Path.Combine(folder, $"{name}_{scaleInt}{ext}");
				var tileTempl = Path.Combine(folder, $"{name}_{scaleInt}_{{0}}{ext}");
				// force png32 format to avoid 1-bit transparent png's
				if (src.EndsWith(".png"))
					tileTempl = "png32:" + tileTempl;
				ImageMagick.ResizeImage(newFile, src, (int)(size.Width * tileScale), (int)(size.Height * tileScale));
				ImageMagick.CreateTiles(src, tileTempl, TileSize, TileSize);
				File.Delete(src);
			}

			var fullName = name + "_{0}_{1}_{2}" + ext;
			if (puzzle)
			{
				var placeholder = Path.Combine(folder, string.Format(fullName, "ph", 0, 0));
				if (size.Width > PlaceholderSize || size.Height > PlaceholderSize)
					ImageMagick.ScaleImage(newFile, placeholder, PlaceholderSize, PlaceholderSize);
				else
					File.Copy(newFile, placeholder);
			}
			return fullName;
		}

		public static void DeleteTiles(string folder, string oldFile)
		{
			if (string.IsNullOrEmpty(oldFile))
				return;

			foreach (var file in Directory.GetFiles(Path.Combine(TempFolder, folder), string.Format(oldFile, "*", "*", "*")))
				File.Delete(file);
		}

		public static void DeleteFolder(int errorCount = 0)
		{
			try
			{
				if (Directory.Exists(TempFolder))
					Directory.Delete(TempFolder, true);
			}
			catch
			{
				if (errorCount > 10)
					throw;

				Thread.Sleep(100);
				errorCount++;
				DeleteFolder(errorCount);
			}
		}

		public static void CreateFolders()
		{
			foreach (var folder in new string[] { FolderLayers, FolderSounds })
			{
				var path = Path.Combine(TempFolder, folder);
				if (!Directory.Exists(path))
					Directory.CreateDirectory(path);
			}
		}
	}
}
