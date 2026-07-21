using Comics.Editor.Utils;
using IWS.Utils;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Comics.Editor.Models
{
	public class Comics
	{
		private const string FileName = "data.json";

		public int Width { get; set; }

		public int Height { get; set; }

		public List<Layer> Layers { get; set; } = new List<Layer>();

		public List<Sound> Sounds { get; set; } = new List<Sound>();

		public void Save()
		{
			File.WriteAllText(Path.Combine(FileManager.TempFolder, FileName), this.ToJson(), Encoding.UTF8);
		}

		public static Comics Load()
		{
			var path = Path.Combine(FileManager.TempFolder, FileName);
			var comics = File.Exists(path) ? File.ReadAllText(path, Encoding.UTF8).FromJson<Comics>() : null;
			return comics ?? new Comics { Width = 1080, Height = 2160 };
		}
	}
}
