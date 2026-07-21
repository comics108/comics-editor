using AutoMapper.QueryableExtensions;
using Comics.DAL;
using Comics.DAL.Model;
using Comics.Web.Areas.Admin.Models;
using IWS.Utils;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Api.Models
{
	public enum PushTypes
	{
		None,
		Quote,
		Comics,
		Puzzle,
		Music
	}

	public class PushMessage
	{
		public PushTypes Type { get; set; }

		public string Title { get; set; }

		public string Text { get; set; }

		public PushMessage(PushTypes type, string title, string text)
		{
			Type = type;
			Title = title;
			Text = text;
		}

		public static void ProcessNotification(Db db, NotificationModel model)
		{
			var dataEmpty = new PushMessage(model.Type, null, null).ToJson();
			foreach (var device in PushDevice.Load(db))
			{
				var title = model.TitleToken.GetText(device.Culture);
				var text = model.TextToken.GetText(device.Culture);
				var data = new PushMessage(model.Type, title, text).ToJson();
				PushManager.Send(device.Platform, device.PushToken, title, text, data, dataEmpty);
			}
		}

		public static void ProcessQuotes(Db db)
		{
			var quote = Quote.Day(db);
			if (quote == null)
				return;

			var dataEmpty = new PushMessage(PushTypes.Quote, null, null).ToJson();
			foreach (var device in PushDevice.Load(db))
			{
				var title = device.Culture == Cultures.Ru ? "Цитата дня" : "Quote of the day";
				var text = quote.NameToken.GetText(device.Culture);
				var data = new PushMessage(PushTypes.Quote, title, text).ToJson();
				PushManager.Send(device.Platform, device.PushToken, title, text, data, dataEmpty);
			}
		}

		public static void ProcessPuzzle(Db db)
		{
			var piece = Piece.Load(db).Where(x => x.Date == DateTime.Today).FirstOrDefault();
			if (piece == null)
				return;

			var dataEmpty = new PushMessage(PushTypes.Puzzle, null, null).ToJson();
			foreach (var device in PushDevice.Load(db))
			{
				var title = piece.Puzzle.NameToken.GetText(device.Culture);
				var text = device.Culture == Cultures.Ru ? "Доступен новый персонаж" : "New character available";
				var data = new PushMessage(PushTypes.Puzzle, title, text).ToJson();
				PushManager.Send(device.Platform, device.PushToken, title, text, data, dataEmpty);
			}
		}
	}

	public class PushDevice
	{
		public PlatformTypes Platform { get; set; }

		public string PushToken { get; set; }

		public Cultures Culture { get; set; }

		public static List<PushDevice> Load(Db db)
		{
			return Device.LoadPush(db).ProjectTo<PushDevice>().ToList();
		}
	}
}