using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Comics.DAL.Model
{
	[Table("TokensLocalized")]
	public class TokenLocalized
	{
		[Key, Column(Order = 0)]
		public int Id { get; set; }

		[Key, Column(Order = 1)]
		public Cultures Culture { get; set; }

		[MaxLength]
		public string Text { get; set; }

		public virtual Token Token { get; set; }
	}
}
