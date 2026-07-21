using AutoMapper;
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
	/// Методы регистрации / авторизации
	/// </summary>
	public class AuthController : DbController<Db>
	{
		/// <summary>
		/// Регистрация / обновление информации об устройстве пользователя.
		/// Во все запросы нужно передавать User-Agent в формате {app_package}/{app_version} ({device_model}; {platform} {os_version}),
		/// язык через http-заголовок accept-language (поддерживаются en и ru),
		/// токен устройства в http-заголовке Authorization: Mahabharata {token}.
		/// </summary>
		/// <returns>Токен устройства</returns>
		[HttpPost]
		public ApiResult<TokenModel> UpdateDevice(DeviceModel model)
		{
			int tzOffset = (int)Math.Round((model.LocalTime.FromUnixTimeStamp() - DateTime.UtcNow).TotalHours);
			if (tzOffset < -12 || tzOffset > 12 || string.IsNullOrEmpty(model.DeviceId))
				return ApiResult.CreateException(ApiResultCode.InvalidInputData, "Invalid local time or device id");

			var deviceInfo = DeviceInfo.Create(Request.Headers.UserAgent);
			if (deviceInfo == null)
				return ApiResult.CreateException(ApiResultCode.InvalidInputData, "Invalid user agent");

			var device = Device.Update(Db, TokenAuthorizeAttribute.GetToken(ActionContext), deviceInfo.Platform, deviceInfo.OsVersion, model.DeviceId, deviceInfo.Model, deviceInfo.AppVersion, tzOffset, CulturesHelper.Current);
			return Mapper.Map<TokenModel>(device);
		}

		/// <summary>
		/// Обновление push-токена устройства
		/// </summary>
		[HttpPost]
		[TokenAuthorize]
		public ApiResult UpdatePushToken(TokenModel model)
		{
			if (string.IsNullOrEmpty(model.Token))
				return ApiResult.CreateException(ApiResultCode.InvalidInputData, "Invalid push token");

			var device = Device.Load(Db, TokenAuthorizeAttribute.GetToken(ActionContext));
			if (device != null)
			{
				device.PushToken = model.Token;
				Db.SaveChanges();
			}
			return ApiResult.Success;
		}
	}
}