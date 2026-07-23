// SDD sdd-comics-editor-v2.9 (обвязка): реализация методов поверх существующего кода
// (Comics.Load/Save, FileManager, формат data.json + layers/ + sounds/ в zip).
// Zip: System.IO.Compression вместо Utils\7za.exe — тот же формат -tzip, но работает
// на всех платформах (7za.exe остаётся для WPF-редактора на Windows).

using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Runtime.InteropServices;

using Comics.Editor.Utils;
using IWS.Utils;
using Newtonsoft.Json.Linq;

using ComicsModel = Comics.Editor.Models.Comics;

namespace Comics.Editor.Headless
{
	public static class Rpc
	{
		public static JToken Dispatch(string method, JObject args)
		{
			switch (method)
			{
				case "ping":
					return new JObject { ["pong"] = true, ["version"] = "2.9", ["tempFolder"] = FileManager.TempFolder };
				case "openComics":
					return OpenComics(RequirePath(args));
				case "saveComics":
					return SaveComics(RequirePath(args), args["comics"] as JObject);
				case "exportPackage":
					return ExportPackage(RequirePath(args));
				case "imageInfo":
					return ImageInfo(RequirePath(args));
				default:
					throw new InvalidOperationException("Unknown method: " + method);
			}
		}

		private static string RequirePath(JObject args)
		{
			var path = (string)args["path"];
			if (string.IsNullOrEmpty(path))
				throw new ArgumentException("params.path is required");
			return path;
		}

		/// <summary>Распаковывает .comics/.puzzle во временную папку редактора и возвращает data.json.</summary>
		private static JToken OpenComics(string path)
		{
			if (!File.Exists(path))
				throw new FileNotFoundException("File not found", path);

			FileManager.DeleteFolder();
			Directory.CreateDirectory(FileManager.TempFolder);
			ZipFile.ExtractToDirectory(path, FileManager.TempFolder, overwriteFiles: true);
			FileManager.CreateFolders();

			var comics = ComicsModel.Load();
			return new JObject
			{
				["comics"] = JObject.Parse(comics.ToJson()),
				["tempFolder"] = FileManager.TempFolder,
			};
		}

		/// <summary>Пишет data.json (существующей сериализацией) и упаковывает temp-папку в .comics.</summary>
		private static JToken SaveComics(string path, JObject comicsJson)
		{
			if (!Directory.Exists(FileManager.TempFolder))
				throw new InvalidOperationException("No opened comics: call openComics first");

			if (comicsJson != null)
			{
				var comics = comicsJson.ToString().FromJson<ComicsModel>();
				if (comics == null)
					throw new ArgumentException("params.comics is not a valid comics document");
				comics.Save();
			}

			ZipTempTo(path);
			return true;
		}

		/// <summary>Упаковывает текущее состояние temp-папки без изменения data.json.</summary>
		private static JToken ExportPackage(string path)
		{
			if (!Directory.Exists(FileManager.TempFolder))
				throw new InvalidOperationException("No opened comics: call openComics first");

			ZipTempTo(path);
			return true;
		}

		private static void ZipTempTo(string path)
		{
			if (File.Exists(path))
				File.Delete(path);
			ZipFile.CreateFromDirectory(FileManager.TempFolder, path, CompressionLevel.Optimal, includeBaseDirectory: false);
		}

		/// <summary>Размер изображения через ImageMagick: exe редактора на Windows, системный magick на unix.</summary>
		private static JToken ImageInfo(string path)
		{
			if (!File.Exists(path))
				throw new FileNotFoundException("File not found", path);

			var magick = ResolveMagick();
			var psi = new ProcessStartInfo
			{
				FileName = magick,
				Arguments = string.Format(@"identify -format ""%[fx:w]x%[fx:h]"" ""{0}""", path),
				UseShellExecute = false,
				RedirectStandardOutput = true,
				CreateNoWindow = true,
			};
			using (var proc = Process.Start(psi))
			{
				var output = proc.StandardOutput.ReadToEnd().Trim();
				proc.WaitForExit();
				var parts = output.Split('x');
				return new JObject { ["width"] = int.Parse(parts[0]), ["height"] = int.Parse(parts[1]) };
			}
		}

		private static string ResolveMagick()
		{
			if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
			{
				var local = Path.Combine(AppContext.BaseDirectory, "Utils", "ImageMagick", "magick.exe");
				if (File.Exists(local))
					return local;
			}
			// unix: системный ImageMagick (`brew install imagemagick` / `apt install imagemagick`)
			return "magick";
		}
	}
}
