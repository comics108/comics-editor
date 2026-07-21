using Comics.DAL;
using Comics.DAL.Model;
using Comics.Web.Areas.Api.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Admin.Models
{
	public class NotificationModel
	{
		public PushTypes Type { get; set; }

		public Token TitleToken { get; set; }

		public Token TextToken { get; set; }

		public void Load(Db db)
		{
		}

		public void Update(Db db)
		{
			PushMessage.ProcessNotification(db, this);
		}

		public static NotificationModel Create()
		{
			return new NotificationModel
			{
				TitleToken = Token.Create(nameof(NotificationModel), "Title", 0),
				TextToken = Token.Create(nameof(NotificationModel), "Text", 0)
			};
		}
	}
}