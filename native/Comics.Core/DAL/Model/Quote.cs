using IWS.Utils;
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
	public class Quote
	{
		[Key]
		public int Id { get; set; }

		public int NameTokenId { get; set; }

		public int ImageTokenId { get; set; }

		[Display(Name = "Publish Date")]
		public DateTime? PublishDate { get; set; }

		public virtual Token NameToken { get; set; }

		public virtual Token ImageToken { get; set; }

		[NotMapped]
		public string Name
		{
			get { return NameToken.Current.Text; }
			set { NameToken.Current.Text = value; }
		}

		[NotMapped]
		public string Image
		{
			get { return ImageToken.Current.Text; }
			set { ImageToken.Current.Text = value; }
		}

		public void UpdateTokenKeys()
		{
			NameToken.Key = Token.BuildKey(nameof(Quote), nameof(Name), Id);
			ImageToken.Key = Token.BuildKey(nameof(Quote), nameof(Image), Id);
		}

		public void Update(Db db)
		{
			NameToken.Update(db, true);
			ImageToken.Update(db, true);

			if (Id == 0)
				db.Quotes.Add(this);
			else
				db.Entry(this).State = EntityState.Modified;
		}

		public void Delete(Db db)
		{
			NameToken.Delete(db);
			ImageToken.LocalizedTokens.ForEach(x => ImageManager.Delete(x.Text));
			ImageToken.Delete(db);
			db.Quotes.Remove(this);
		}

		public static Quote Create(Db db)
		{
			return new Quote
			{
				NameToken = Token.Create(nameof(Quote), nameof(Name), 0),
				ImageToken = Token.Create(nameof(Quote), nameof(Image), 0)
			};
		}

		public static IQueryable<Quote> Load(Db db)
		{
			return db.Quotes.AsNoTracking().Include(x => x.NameToken.LocalizedTokens).Include(x => x.ImageToken.LocalizedTokens);
		}

		public static Quote Load(Db db, int id)
		{
			return db.Quotes.FirstOrDefault(x => x.Id == id);
		}

		public static Quote Day(Db db)
		{
			var quote = db.Quotes.Where(x => !x.PublishDate.HasValue).OrderBy(x => Guid.NewGuid()).FirstOrDefault();
			if (quote == null)
				return null;

			quote.PublishDate = DateTime.UtcNow;
			db.SaveChanges();
			return quote;
		}
	}
}
