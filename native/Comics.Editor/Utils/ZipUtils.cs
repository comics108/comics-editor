using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Comics.Editor.Utils
{
	public static class ZipUtils
	{
		/// <summary>
		/// Creates a zip archive
		/// </summary>
		/// <param name="srcPath">Source folder</param>
		/// <param name="dstPath">Archive path</param>
		/// <param name="compressionLevel">Compression level (0 - 9)</param>
		public static void Zip(string srcPath, string dstPath, int compressionLevel = 5)
		{
			RunProcess(@"Utils\7za.exe", string.Format(@"a -tzip -mx{0} ""{1}"" ""{2}""", compressionLevel, dstPath, srcPath));
		}

		/// <summary>
		/// Unpack a zip archive
		/// </summary>
		/// <param name="srcPath">Archive path</param>
		/// <param name="dstPath">Destination folder</param>
		public static void Unzip(string srcPath, string dstPath)
		{
			RunProcess(@"Utils\7za.exe", string.Format(@"x ""{0}"" -o""{1}""", srcPath, dstPath));
		}

		private static string RunProcess(string fileName, string arguments)
		{
			using (var proc = new Process())
			{
				proc.StartInfo.WindowStyle = ProcessWindowStyle.Hidden;
				proc.StartInfo.UseShellExecute = false;
				proc.StartInfo.RedirectStandardOutput = true;
				proc.StartInfo.FileName = fileName;
				proc.StartInfo.Arguments = arguments;
				proc.StartInfo.ErrorDialog = false;
				proc.StartInfo.CreateNoWindow = true;

				proc.Start();
				var output = proc.StandardOutput.ReadToEnd();
				proc.WaitForExit();
				return output;
			}
		}
	}
}
