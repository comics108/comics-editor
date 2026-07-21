using System;
using System.Collections.Generic;
using System.Data.Entity.Migrations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Comics.DAL.Migrations
{
	public class DbConfig : DbMigrationsConfiguration<Db>
	{
		public DbConfig()
		{
			AutomaticMigrationsEnabled = true;
			AutomaticMigrationDataLossAllowed = true;
		}
	}
}
