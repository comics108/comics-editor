using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;

namespace IWS.Mvc
{
	public class DbController<T> : Controller
		where T : IDisposable, new()
	{
		protected T Db { get; private set; }

		public DbController()
		{
			Db = new T();
		}

		protected override void Dispose(bool disposing)
		{
			if (disposing)
				Db.Dispose();
			base.Dispose(disposing);
		}
	}
}