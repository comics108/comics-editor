using IWS.Utils;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Data.Entity;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Comics.DAL.Model
{
	public class Episode
	{
		public static readonly Size ImageSize = new Size(944, 1376);

		[Key]
		public int Id { get; set; }

		[Display(Name = "Season")]
		public int SeasonId { get; set; }

		public int NameTokenId { get; set; }

		[StringLength(256)]
		[UIHint("Image")]
		public string Image { get; set; }

		[StringLength(256)]
		[UIHint("File")]
		public string File { get; set; }

		public int Version { get; set; }

		[StringLength(256)]
		[Display(Name = "Google Play / App Store Product")]
		public string Product { get; set; }

		[DataType(DataType.Date)]
		[DisplayFormat(DataFormatString = "{0:dd.MM.yyyy}", ApplyFormatInEditMode = true)]
		[UIHint("DateTime")]
		public DateTime Date { get; set; }

		[Display(Name = "Number")]
		public int Order { get; set; }

		public virtual Season Season { get; set; }

		public virtual Token NameToken { get; set; }

		[NotMapped]
		public string Name
		{
			get { return NameToken.Current.Text; }
			set { NameToken.Current.Text = value; }
		}

		[NotMapped]
		public string Number
		{
			get { return "Chapter " + Order; }
		}

		public void UpdateTokenKeys()
		{
			NameToken.Key = Token.BuildKey(nameof(Episode), nameof(Name), Id);
		}

		public void Update(Db db)
		{
			NameToken.Update(db, true);

			if (Id == 0)
				db.Episodes.Add(this);
			else
				db.Entry(this).State = EntityState.Modified;
		}

		public void Delete(Db db)
		{
			ImageManager.Delete(Image);
			ImageManager.Delete(File);
			Move(db, 1000);
			NameToken.Delete(db);
			db.Episodes.Remove(this);
		}

		public void Move(Db db, int offset)
		{
			if (offset == 0)
				return;

			var query = db.Episodes.Where(x => x.SeasonId == SeasonId);
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

		public static Episode Create(Db db, int? seasonId)
		{
			var season = seasonId.HasValue ? Season.Load(db, seasonId.Value) : null;
			if (season == null)
				return null;

			var query = db.Episodes.Where(x => x.SeasonId == seasonId);
			var order = query.Any() ? query.Max(x => x.Order) + 1 : 1;
			return new Episode
			{
				SeasonId = season.Id,
				Season = season,
				Version = 1,
				Order = order,
				Date = DateTime.Today,
				NameToken = Token.Create(nameof(Episode), nameof(Name), 0)
			};
		}

		public static IQueryable<Episode> Load(Db db)
		{
			return db.Episodes.AsNoTracking().Include(x => x.NameToken.LocalizedTokens);
		}

		public static Episode Load(Db db, int id)
		{
			return db.Episodes.FirstOrDefault(x => x.Id == id);
		}
	}
}
