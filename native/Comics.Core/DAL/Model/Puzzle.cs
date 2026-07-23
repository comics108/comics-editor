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
	public class Puzzle
	{
		[Key]
		public int Id { get; set; }

		public int NameTokenId { get; set; }

		public int Width { get; set; }

		public int Height { get; set; }

		public int Order { get; set; }

		public virtual Token NameToken { get; set; }

		public virtual List<Piece> Pieces { get; set; }

		[NotMapped]
		public string Name
		{
			get { return NameToken.Current.Text; }
			set { NameToken.Current.Text = value; }
		}

		public void UpdateTokenKeys()
		{
			NameToken.Key = Token.BuildKey(nameof(Puzzle), nameof(Name), Id);
		}

		public void Update(Db db)
		{
			NameToken.Update(db, true);

			if (Id == 0)
				db.Puzzles.Add(this);
			else
				db.Entry(this).State = EntityState.Modified;
		}

		public void Delete(Db db)
		{
			Move(db, 1000);
			NameToken.Delete(db);
			db.Puzzles.Remove(this);
		}

		public void Move(Db db, int offset)
		{
			if (offset == 0)
				return;

			var query = db.Puzzles.AsQueryable();
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

		public static Puzzle Create(Db db)
		{
			var query = Load(db);
			var order = query.Any() ? query.Max(x => x.Order) + 1 : 1;
			return new Puzzle
			{
				Order = order,
				NameToken = Token.Create(nameof(Puzzle), nameof(Name), 0)
			};
		}

		public static IQueryable<Puzzle> Load(Db db)
		{
			return db.Puzzles.AsNoTracking().Include(x => x.NameToken.LocalizedTokens).OrderBy(x => x.Order);
		}

		public static List<Puzzle> LoadAll(Db db)
		{
			var date = DateTime.Today;
			var items = Load(db).Include(x => x.Pieces).ToList();
			items.ForEach(x => x.Pieces = x.Pieces.Where(y => y.Date <= date).OrderBy(y => y.Order).ToList());
			return items;
		}

		public static Puzzle Load(Db db, int id)
		{
			return db.Puzzles.FirstOrDefault(x => x.Id == id);
		}
	}
}
