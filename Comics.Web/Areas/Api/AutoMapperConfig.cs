using AutoMapper;
using Comics.DAL.Model;
using Comics.Web.Areas.Api.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Comics.Web.Areas.Api
{
	public static class AutoMapperConfig
	{
		public static void Configure()
		{
			Mapper.Initialize(Initialize);
		}

		private static void Initialize(IMapperConfigurationExpression config)
		{
			config.CreateMap<Season, SeasonModel>();
			config.CreateMap<Episode, EpisodeModel>();
			config.CreateMap<Puzzle, PuzzleModel>();
			config.CreateMap<Piece, PieceModel>();
			config.CreateMap<Quote, QuoteModel>();
			config.CreateMap<Music, MusicModel>();
			config.CreateMap<Device, TokenModel>()
				.ForMember(x => x.Token, opt => opt.MapFrom(x => x.Id.ToString("N")));
			config.CreateMap<Device, PushDevice>();
		}
	}
}