using System;
using System.Collections.Generic;
using System.Data.Entity;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using IWS.Utils;
using Comics.DAL.Model;

namespace Comics.DAL
{
	public class Db : DbContext
	{
		public DbSet<Token> Tokens { get; set; }

		public DbSet<TokenLocalized> TokensLocalized { get; set; }

		public DbSet<Season> Seasons { get; set; }

		public DbSet<Episode> Episodes { get; set; }

		public DbSet<Puzzle> Puzzles { get; set; }

		public DbSet<Piece> Pieces { get; set; }

		public DbSet<Quote> Quotes { get; set; }

		public DbSet<Music> Music { get; set; }

		public DbSet<Device> Devices { get; set; }

		public Db()
			: base(WebConfig.ConnectionString)
		{
		}

		protected override void OnModelCreating(DbModelBuilder modelBuilder)
		{
			base.OnModelCreating(modelBuilder);

			modelBuilder.Entity<Season>().HasRequired(x => x.NameToken).WithMany().HasForeignKey(x => x.NameTokenId).WillCascadeOnDelete(false);
			modelBuilder.Entity<Quote>().HasRequired(x => x.NameToken).WithMany().HasForeignKey(x => x.NameTokenId).WillCascadeOnDelete(false);
			modelBuilder.Entity<Quote>().HasRequired(x => x.ImageToken).WithMany().HasForeignKey(x => x.ImageTokenId).WillCascadeOnDelete(false);
			modelBuilder.Entity<Music>().HasRequired(x => x.NameToken).WithMany().HasForeignKey(x => x.NameTokenId).WillCascadeOnDelete(false);
		}
	}
}
