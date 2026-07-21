using Comics.DAL;
using Comics.Web.Areas.Api.Models;
using IWS.WebApi;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Http;

namespace Comics.Web.Areas.Api.Controllers
{
	/// <summary>
	/// Методы управления и обработки данных. В мобильном приложении не используются
	/// </summary>
	[IpFilter]
	public class AdminController : DbController<Db>
	{
		/// <summary>
		/// Выбор и рассылка цитаты дня пользователям.
		/// </summary>
		[HttpGet]
		public ApiResult DayQuotes()
		{
			PushMessage.ProcessQuotes(Db);
			return ApiResult.Success;
		}

		/// <summary>
		/// Проверка и рассылка наличия новых персонажей в битве.
		/// </summary>
		[HttpGet]
		public ApiResult Puzzle()
		{
			PushMessage.ProcessPuzzle(Db);
			return ApiResult.Success;
		}
	}
}