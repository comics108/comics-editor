using Comics.Editor.Utils;
using IWS.Utils;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Comics.Editor.Models
{
	public class Layer
	{
		public bool Preview { get; set; }

		public List<Image> Images { get; set; } = new List<Image>();

		public ObservableCollection<Anim> Animations { get; set; } = new ObservableCollection<Anim>();

		public Image GetImage(Cultures culture, bool returnDefault = true)
		{
			var index = CulturesHelper.All.IndexOf(culture);
			var image = index >= 0 && index < Images.Count ? Images[index] : null;
			return string.IsNullOrEmpty(image.File) && returnDefault ? Images.FirstOrDefault() : image;
		}

		public void SetImage(Cultures culture, string file, bool puzzle, bool popup)
		{
			Images[CulturesHelper.All.IndexOf(culture)].Update(FileManager.FolderLayers, file, puzzle, popup);
		}

		public void Delete()
		{
			Images.ForEach(x => x.Delete(FileManager.FolderLayers));
		}

		public static Layer Create(string file, double scroll, bool puzzle)
		{
			var layer = new Layer();
			for (int i = 0; i < CulturesHelper.All.Count; i++)
			{
				var image = new Image();
				layer.Images.Add(image);
				if (i == 0)
					image.Update(FileManager.FolderLayers, file, puzzle, false);
			}
			if (layer.Images.All(x => string.IsNullOrEmpty(x.File)))
				return null;

			layer.Animations.Add(new TranslateAnim { Y = (int)scroll });
			return layer;
		}
	}
}
