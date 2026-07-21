using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Api.Models
{
	public class PuzzleModel
	{
		public int Id { get; set; }

		public string Name { get; set; }

		public int Width { get; set; }

		public int Height { get; set; }

		public int Order { get; set; }

		public List<PieceModel> Pieces { get; set; }
	}
}