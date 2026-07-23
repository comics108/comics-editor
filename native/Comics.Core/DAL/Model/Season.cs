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
	public class Season
	{
		[Key]
		public int Id { get; set; }

		public int NameTokenId { get; set; }

		[StringLength(256)]
		[UIHint("Image")]
		public string Image { get; set; }

		[StringLength(256)]
		[Display(Name = "Google Play / App Store Product")]
		public string Product { get; set; }

		[Display(Name = "Number")]
		public int Order { get; set; }

		public virtual Token NameToken { get; set; }

		public virtual List<Episode> Episodes { get; set; }

		[NotMapped]
		public string Name
		{
			get { return NameToken.Current.Text; }
			set { NameToken.Current.Text = value; }
		}

		[NotMapped]
		public string Number
		{
			get { return "Book " + Order; }
		}

		public void UpdateTokenKeys()
		{
			NameToken.Key = Token.BuildKey(nameof(Season), nameof(Name), Id);
		}

		public void Update(Db db)
		{
			NameToken.Update(db, true);

			if (Id == 0)
				db.Seasons.Add(this);
			else
				db.Entry(this).State = EntityState.Modified;
		}

		public void Delete(Db db)
		{
			ImageManager.Delete(Image);
			Move(db, 1000);
			NameToken.Delete(db);
			db.Seasons.Remove(this);
		}

		public void Move(Db db, int offset)
		{
			if (offset == 0)
				return;

			var query = db.Seasons.AsQueryable();
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

		public static Season Create(Db db)
		{
			var query = Load(db);
			var order = query.Any() ? query.Max(x => x.Order) + 1 : 1;
			return new Season
			{
				Order = order,
				NameToken = Token.Create(nameof(Season), nameof(Name), 0)
			};
		}

		public static IQueryable<Season> Load(Db db)
		{
			return db.Seasons.AsNoTracking().OrderBy(x => x.Order);
		}

		public static List<Season> LoadAll(Db db)
		{
			var items = db.Seasons.AsNoTracking().Include(x => x.NameToken.LocalizedTokens).Include(x => x.Episodes.Select(y => y.NameToken.LocalizedTokens)).OrderBy(x => x.Order).ToList();
			items.ForEach(x => x.Episodes = x.Episodes.OrderBy(y => y.Order).ToList());
			return items;
		}

		public static Season Load(Db db, int id)
		{
			return db.Seasons.FirstOrDefault(x => x.Id == id);
		}
	}
}
