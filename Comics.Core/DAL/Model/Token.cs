using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Data.Entity;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Comics.DAL.Model
{
	public class Token
	{
		[Key]
		public int Id { get; set; }

		[Required]
		[StringLength(100)]
		public string Key { get; set; }

		public virtual List<TokenLocalized> LocalizedTokens { get; set; }

		[NotMapped]
		public TokenLocalized Current
		{
			get { return LocalizedTokens.FirstOrDefault(x => x.Culture == CulturesHelper.Current); }
			set
			{
				if (Current == null)
					LocalizedTokens.Add(value);
			}
		}

		public Token()
		{
			LocalizedTokens = new List<TokenLocalized>();
		}

		public string GetText(Cultures culture)
		{
			return LocalizedTokens.FirstOrDefault(x => x.Culture == culture)?.Text;
		}

		public void Update(Db db, bool full = false)
		{
			if (Id == 0)
			{
				var cultures = LocalizedTokens.Select(x => x.Culture);
				foreach (var culture in CulturesHelper.All.Where(x => !cultures.Contains(x)))
					LocalizedTokens.Add(new TokenLocalized() { Culture = culture });
				db.Tokens.Add(this);
				return;
			}

			db.Entry(this).State = EntityState.Modified;
			if (full)
			{
				foreach (var item in LocalizedTokens)
					db.Entry(item).State = EntityState.Modified;
			}
			else
				db.Entry(Current).State = EntityState.Modified;
		}

		public void Delete(Db db)
		{
			db.Tokens.Remove(this);
		}

		public static Token Create()
		{
			return Create(null);
		}

		public static Token Create(string type, int id, params string[] texts)
		{
			return Create(type, null, id, texts);
		}

		public static Token Create(string type, string field, int id, params string[] texts)
		{
			var key = BuildKey(type, field, id);
			return Create(key, texts);
		}

		public static Token Create(string key, params string[] texts)
		{
			var token = new Token()
			{
				Key = key
			};
			for (int i = 0; i < CulturesHelper.All.Length; i++)
				token.LocalizedTokens.Add(new TokenLocalized() { Culture = CulturesHelper.All[i], Text = i < texts.Length ? texts[i] : null });
			return token;
		}

		public static string BuildKey(string type, string field, int id)
		{
			var key = type + "." + id;
			if (!string.IsNullOrEmpty(field))
				key += "." + field;
			return key;
		}

		public static void SetKey(Token token, string type, string field, int id)
		{
			if (token != null)
				token.Key = BuildKey(type, field, id);
		}

		public static List<Token> Load(Db db)
		{
			return db.Tokens.Include(x => x.LocalizedTokens).OrderBy(x => x.Key).ToList();
		}

		public static Token Update(Db db, Token token, bool removeEmpty = false, bool full = false)
		{
			if (token == null)
				return token;

			if (!removeEmpty || token.LocalizedTokens.Any(x => !string.IsNullOrEmpty(x.Text)))
			{
				token.Update(db, full);
				return token;
			}

			if (token.Id > 0)
			{
				token.Update(db, full);
				token.Delete(db);
			}
			return null;
		}
	}
}
