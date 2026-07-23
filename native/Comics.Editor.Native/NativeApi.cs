// SDD sdd-comics-editor-v2.9-android-ios (обвязка): C-экспорты поверх Rpc.Dispatch
// для dart:ffi. Протокол тот же, что у NDJSON-хоста: JSON-запрос → JSON-ответ
// ({"result":…} | {"error":{…}}), меняется только транспорт.

using System;
using System.Runtime.InteropServices;

using Newtonsoft.Json.Linq;

namespace Comics.Editor.Headless
{
	public static class NativeApi
	{
		/// <summary>
		/// comics_call(method_utf8, params_json_utf8) → JSON-ответ (UTF-8).
		/// Возвращённый указатель освобождается вызывающим через comics_free.
		/// </summary>
		[UnmanagedCallersOnly(EntryPoint = "comics_call")]
		public static IntPtr ComicsCall(IntPtr methodUtf8, IntPtr paramsUtf8)
		{
			JObject response;
			try
			{
				var method = Marshal.PtrToStringUTF8(methodUtf8);
				var paramsJson = paramsUtf8 == IntPtr.Zero ? null : Marshal.PtrToStringUTF8(paramsUtf8);
				var args = string.IsNullOrEmpty(paramsJson) ? new JObject() : JObject.Parse(paramsJson);

				var result = Rpc.Dispatch(method, args);
				response = new JObject { ["result"] = result };
			}
			catch (Exception e)
			{
				response = new JObject
				{
					["error"] = new JObject
					{
						["message"] = e.Message,
						["type"] = e.GetType().Name,
					},
				};
			}

			return Marshal.StringToCoTaskMemUTF8(response.ToString(Newtonsoft.Json.Formatting.None));
		}

		[UnmanagedCallersOnly(EntryPoint = "comics_free")]
		public static void ComicsFree(IntPtr ptr)
		{
			Marshal.FreeCoTaskMem(ptr);
		}

		/// <summary>
		/// Установка переменной окружения до первого вызова ядра
		/// (HOME/XDG_DATA_HOME для песочницы iOS/Android — см. Task 3.5).
		/// </summary>
		[UnmanagedCallersOnly(EntryPoint = "comics_set_env")]
		public static void ComicsSetEnv(IntPtr nameUtf8, IntPtr valueUtf8)
		{
			var name = Marshal.PtrToStringUTF8(nameUtf8);
			if (string.IsNullOrEmpty(name))
				return;
			Environment.SetEnvironmentVariable(name, Marshal.PtrToStringUTF8(valueUtf8));
		}
	}
}
