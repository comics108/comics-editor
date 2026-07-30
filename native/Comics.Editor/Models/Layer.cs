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

		// vdd-comics-editor-uiux-lettering: additive fields for balloon/lettering support.
		// Left as plain nullable properties (not eagerly initialized, unlike Images/Animations
		// above) specifically so DefaultValueHandling.Ignore (Extensions.SerializerSettings) omits
		// them entirely from JSON when unset -- Json.NET's default-value check compares against
		// default(T), which for a reference type is null, not an empty collection. A legacy layer,
		// or any layer this feature never touches, round-trips through save with these three keys
		// completely absent, byte-identical to today's output.

		/// <summary>Coarse layer classification. This flow only assigns/reads "balloon" and
		/// "caption"; left as an open string (not an enum) so a broader taxonomy explored
		/// elsewhere (see flows/vdd-comics-editor-jhanava/) can reuse this same field later
		/// without a schema migration. Null/absent = today's untyped/generic layer.</summary>
		public string Kind { get; set; }

		/// <summary>Balloon-specific refinement of <see cref="Kind"/>: "speech" or
		/// "hand_lettered" (the latter sourced from apps/comics-ai-baloons' classify.py output
		/// when applicable). Meaningless when Kind != "balloon"; not read/written otherwise.</summary>
		public string Style { get; set; }

		/// <summary>Per-language balloon text, keyed by ISO language code (e.g. "en", "ru", "uk").
		/// Independent of <see cref="Images"/>/Cultures -- a language can have text here with no
		/// corresponding rendered artwork yet. Not capped to any fixed language count (see
		/// LanguageRegistry on the Dart side); may hold languages beyond the 3 Cultures values.
		/// Use <see cref="TranslationsOrEmpty"/> to read without a null check.</summary>
		public Dictionary<string, string> Translations { get; set; }

		[JsonIgnore]
		public IReadOnlyDictionary<string, string> TranslationsOrEmpty =>
			Translations ?? EmptyTranslations;

		[JsonIgnore]
		private static readonly Dictionary<string, string> EmptyTranslations = new Dictionary<string, string>();

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
