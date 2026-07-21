using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Http;

namespace IWS.WebApi
{
	public class DbController<T> : ApiController
		where T : IDisposable, new()
	{
		public T Db { get; private set; }

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