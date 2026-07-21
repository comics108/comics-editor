using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Web;

namespace IWS.WebApi
{
	public enum ApiResultCode
	{
		Success,
		Error,
		InvalidInputData,
		RecordNotFound,
		RecordAlreadyExists,
		NeedToLogin,
		UpgradeRequired
	}

	public class ApiResult : ApiResult<object>
	{
		public static readonly ApiResult Success = CreateSuccess();
		public static readonly ApiResult Exception = CreateException();
		public static readonly ApiResult ErrorBadRequest = CreateException(ApiResultCode.InvalidInputData, "Invalid input data.");
		public static readonly ApiResult ErrorNeedToLogin = CreateException(ApiResultCode.NeedToLogin, "You need to login.");
		public static readonly ApiResult UpgradeRequired = CreateException(ApiResultCode.UpgradeRequired, "Upgrade to the latest version is required.");

		public static ApiResult CreateSuccess()
		{
			return new ApiResult
			{
				Code = ApiResultCode.Success
			};
		}

		public static ApiResult CreateException(ApiResultCode exCode = ApiResultCode.Error, string exMessage = "Unexpected Error. Please try again later.")
		{
			return new ApiResult
			{
				Code = exCode,
				Msg = exMessage
			};
		}

		public static ApiResult<T> CreateSuccess<T>(T data)
		{
			return new ApiResult<T>
			{
				Code = ApiResultCode.Success,
				Data = data
			};
		}
	}

	public class ApiResult<T>
	{
		public ApiResultCode Code { get; set; }

		public string Msg { get; set; }

		public T Data { get; set; }

		public bool IsSuccess()
		{
			return Code == ApiResultCode.Success;
		}

		public static implicit operator ApiResult<T>(ApiResult res)
		{
			return new ApiResult<T>
			{
				Code = res.Code,
				Data = res.Data != null ? (T)res.Data : default(T),
				Msg = res.Msg
			};
		}

		public static implicit operator ApiResult(ApiResult<T> res)
		{
			return new ApiResult
			{
				Code = res.Code,
				Data = res.Data,
				Msg = res.Msg
			};
		}

		public static implicit operator ApiResult<T>(T data)
		{
			return ApiResult.CreateSuccess(data);
		}
	}
}