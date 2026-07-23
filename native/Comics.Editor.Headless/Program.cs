// SDD sdd-comics-editor-v2.9 (обвязка): NDJSON-хост поверх существующего кода редактора.
// Протокол: по строке JSON на запрос в stdin, по строке JSON на ответ в stdout.
//   {"id":1,"method":"ping"}
//   {"id":2,"method":"openComics","params":{"path":"/abs/path/file.comics"}}
//   {"id":3,"method":"saveComics","params":{"path":"/abs/path/file.comics","comics":{...}}}
//   {"id":4,"method":"exportPackage","params":{"path":"/abs/path/file.comics"}}
//   {"id":5,"method":"imageInfo","params":{"path":"/abs/path/img.png"}}
// Ответ: {"id":N,"result":...} | {"id":N,"error":{"message":"..."}}

using System;
using System.IO;
using System.Text;

using Newtonsoft.Json.Linq;

namespace Comics.Editor.Headless
{
	public static class Program
	{
		public static int Main()
		{
			Console.InputEncoding = Encoding.UTF8;
			var stdout = new StreamWriter(Console.OpenStandardOutput(), new UTF8Encoding(false)) { AutoFlush = true };

			string line;
			while ((line = Console.In.ReadLine()) != null)
			{
				if (string.IsNullOrWhiteSpace(line))
					continue;

				JToken id = null;
				JObject response;
				try
				{
					var request = JObject.Parse(line);
					id = request["id"];
					var method = (string)request["method"];
					var args = request["params"] as JObject ?? new JObject();

					var result = Rpc.Dispatch(method, args);
					response = new JObject { ["id"] = id, ["result"] = result };
				}
				catch (Exception e)
				{
					response = new JObject
					{
						["id"] = id,
						["error"] = new JObject
						{
							["message"] = e.Message,
							["type"] = e.GetType().Name,
						},
					};
				}

				stdout.WriteLine(response.ToString(Newtonsoft.Json.Formatting.None));
			}

			return 0;
		}
	}
}
