// SDD sdd-comics-editor-v2.9 (обвязка): минимальный shim типов System.Web,
// удалённых из современного .NET. Позволяет компилировать существующий код
// (ImageManager.cs, ImageMagick.cs) без изменений.
// Семантика MapPath: виртуальный путь "~/x" или "/x" → каталог приложения + x.

using System.IO;

namespace System.Web.Hosting
{
	public static class HostingEnvironment
	{
		/// <summary>Корень приложения; по умолчанию — каталог исполняемого файла.</summary>
		public static string ApplicationPhysicalPath { get; set; } = AppContext.BaseDirectory;

		public static string MapPath(string virtualPath)
		{
			if (string.IsNullOrEmpty(virtualPath))
				return ApplicationPhysicalPath;

			var relative = virtualPath.TrimStart('~').TrimStart('/', '\\')
				.Replace('/', Path.DirectorySeparatorChar);
			return Path.Combine(ApplicationPhysicalPath, relative);
		}
	}
}

namespace System.Web
{
	/// <summary>Минимальный аналог System.Web.HttpPostedFileBase (только члены, используемые в коде).</summary>
	public abstract class HttpPostedFileBase
	{
		public abstract int ContentLength { get; }
		public abstract string FileName { get; }
		public abstract Stream InputStream { get; }
		public abstract void SaveAs(string filename);
	}
}
