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
	public class Music
	{
		[Key]
		public int Id { get; set; }

		public int NameTokenId { get; set; }

		public int AuthorTokenId { get; set; }

		[StringLength(256)]
		[UIHint("File")]
		public string File { get; set; }

		public int Order { get; set; }

		public virtual Token NameToken { get; set; }

		public virtual Token AuthorToken { get; set; }

		[NotMapped]
		public string Name
		{
			get { return NameToken.Current.Text; }
			set { NameToken.Current.Text = value; }
		}

		[NotMapped]
		public string Author
		{
			get { return AuthorToken.Current.Text; }
			set { AuthorToken.Current.Text = value; }
		}

		public void UpdateTokenKeys()
		{
			NameToken.Key = Token.BuildKey(nameof(Music), nameof(Name), Id);
			AuthorToken.Key = Token.BuildKey(nameof(Music), nameof(Author), Id);
		}

		public void Update(Db db)
		{
			NameToken.Update(db, true);
			AuthorToken.Update(db, true);

			if (Id == 0)
				db.Music.Add(this);
			else
				db.Entry(this).State = EntityState.Modified;
		}

		public void Delete(Db db)
		{
			ImageManager.Delete(File);
			Move(db, 1000);
			NameToken.Delete(db);
			AuthorToken.Delete(db);
			db.Music.Remove(this);
		}

		public void Move(Db db, int offset)
		{
			if (offset == 0)
				return;

			var query = db.Music.AsQueryable();
			query = (offset > 0) ? query.Where(x => x.Order > Order).OrderBy(x => x.Order).Take(offset) :
				query.Where(x => x.Order < Order).OrderByDescending(x => x.Order).Take(-offset);

			var lastOrder = Order;
			foreach (var item in query)
			{
				var tmpOrder = item.Order;
				item.Order = lastOrder;
				lastOrder = tmpOrder;
			}

			Order = lastOrder;
		}

		public static Music Create(Db db)
		{
			var query = db.Music.AsQueryable();
			var order = query.Any() ? query.Max(x => x.Order) + 1 : 1;
			return new Music
			{
				Order = order,
				NameToken = Token.Create(nameof(Music), nameof(Name), 0),
				AuthorToken = Token.Create(nameof(Music), nameof(Author), 0)
			};
		}

		public static IQueryable<Music> Load(Db db)
		{
			return db.Music.AsNoTracking().Include(x => x.NameToken.LocalizedTokens).Include(x => x.AuthorToken.LocalizedTokens);
		}

		public static Music Load(Db db, int id)
		{
			return db.Music.FirstOrDefault(x => x.Id == id);
		}
	}
}
