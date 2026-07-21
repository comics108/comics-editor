using Comics.DAL;
using Comics.DAL.Model;
using IWS.Mvc;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Admin.Models
{
	public class PiecesParams : ListParams
	{
		public const int PreviewHeight = 500;

		[Display(Name = "Puzzle")]
		public int? PuzzleId { get; set; }

		public List<Puzzle> Puzzles { get; set; }

		public Puzzle Puzzle { get; set; }

		protected override void Update(ListParams savedParams, bool post)
		{
			base.Update(savedParams, post);
			var param = (PiecesParams)savedParams;
			if (!PuzzleId.HasValue)
				PuzzleId = param?.PuzzleId;
		}

		public override IQueryable<T> Filter<T>(IQueryable<T> query)
		{
			var result = (IQueryable<Piece>)query;
			if (PuzzleId > 0)
				result = result.Where(x => x.PuzzleId == PuzzleId.Value);

			return (IQueryable<T>)result;
		}

		public override string OrderBy()
		{
			return "PuzzleId, Order";
		}

		public void Load(Db db)
		{
			Puzzles = Puzzle.Load(db).ToList();
			if (!PuzzleId.HasValue)
				PuzzleId = Puzzles.FirstOrDefault()?.Id;
			Puzzle = Puzzles.FirstOrDefault(x => x.Id == PuzzleId);
		}

		public string Scale(int value)
		{
			var scale = Puzzle != null ? (double)Puzzle.Height / PreviewHeight : 1;
			return (value / scale).ToString(CultureInfo.InvariantCulture);
		}
	}
}