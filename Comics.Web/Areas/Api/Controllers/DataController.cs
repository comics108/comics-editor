using AutoMapper;
using AutoMapper.QueryableExtensions;
using Comics.DAL;
using Comics.DAL.Model;
using Comics.Web.Areas.Api.Models;
using IWS.Utils;
using IWS.WebApi;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Http;

namespace Comics.Web.Areas.Api.Controllers
{
	/// <summary>
	/// Методы получения данных.
	/// </summary>
	[TokenAuthorize]
	public class DataController : DbController<Db>
	{
		/// <summary>
		/// Получение списка сезонов и эпизодов.
		/// </summary>
		[HttpPost]
		public ApiResult<List<SeasonModel>> Seasons()
		{
			return Season.LoadAll(Db).ConvertAll(Mapper.Map<SeasonModel>);
		}

		/// <summary>
		/// Получение списка пазлов.
		/// </summary>
		[HttpPost]
		public ApiResult<List<PuzzleModel>> Puzzles()
		{
			return Puzzle.LoadAll(Db).ConvertAll(Mapper.Map<PuzzleModel>);
		}

		/// <summary>
		/// Получение списка цитат.
		/// </summary>
		[HttpPost]
		public ApiResult<List<QuoteModel>> Quotes()
		{
			return Quote.Load(Db).Where(x => x.PublishDate.HasValue).OrderByDescending(x => x.PublishDate).ToList().ConvertAll(Mapper.Map<QuoteModel>);
		}

		/// <summary>
		/// Получение музыки.
		/// </summary>
		[HttpPost]
		public ApiResult<List<MusicModel>> Music()
		{
			return DAL.Model.Music.Load(Db).OrderBy(x => x.Order).ToList().ConvertAll(Mapper.Map<MusicModel>);
		}

		/// <summary>
		/// Получение списка идентификаторов подписок.
		/// </summary>
		[HttpPost]
		public ApiResult<string[]> Subscriptions()
		{
			return WebConfig.Subscriptions;
		}
	}
}