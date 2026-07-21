using IWS.Utils;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Data.Entity;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Comics.DAL.Model
{
	public class Piece
	{
		[Key]
		public int Id { get; set; }

		[Display(Name = "Puzzle")]
		public int PuzzleId { get; set; }

		public int X { get; set; }

		public int Y { get; set; }

		public int Width { get; set; }

		public int Height { get; set; }

		[StringLength(256)]
		[UIHint("File")]
		public string File { get; set; }

		public int Version { get; set; }

		[DataType(DataType.Date)]
		[DisplayFormat(DataFormatString = "{0:dd.MM.yyyy}", ApplyFormatInEditMode = true)]
		[UIHint("DateTime")]
		public DateTime Date { get; set; }

		public int Order { get; set; }

		public virtual Puzzle Puzzle { get; set; }

		public void Update(Db db)
		{
			if (Id == 0)
				db.Pieces.Add(this);
			else
				db.Entry(this).State = EntityState.Modified;
		}

		public void Delete(Db db)
		{
			ImageManager.Delete(File);
			Move(db, 1000);
			db.Pieces.Remove(this);
		}

		public void Move(Db db, int offset)
		{
			if (offset == 0)
				return;

			var query = db.Pieces.Where(x => x.PuzzleId == PuzzleId);
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

		public static Piece Create(Db db, int? puzzleId)
		{
			var puzzle = puzzleId.HasValue ? Puzzle.Load(db, puzzleId.Value) : null;
			if (puzzle == null)
				return null;

			var query = db.Pieces.Where(x => x.PuzzleId == puzzleId);
			var order = query.Any() ? query.Max(x => x.Order) + 1 : 1;
			return new Piece
			{
				PuzzleId = puzzle.Id,
				Puzzle = puzzle,
				Version = 1,
				Order = order,
				Date = DateTime.Today
			};
		}

		public static IQueryable<Piece> Load(Db db)
		{
			return db.Pieces.AsNoTracking();
		}

		public static Piece Load(Db db, int id)
		{
			return db.Pieces.FirstOrDefault(x => x.Id == id);
		}
	}
}
