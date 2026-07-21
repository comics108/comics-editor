using System;

using log4net;
using log4net.Config;

namespace IWS.Utils
{
	/// <summary>
	/// Log4net log wrapper
	/// </summary>
	public static class Logger
	{
		private static volatile ILog _instance;
		private static object _syncRoot = new Object();

		public static ILog Instance
		{
			get
			{
				if (_instance == null)
				{
					lock (_syncRoot)
					{
						if (_instance == null)
						{
							XmlConfigurator.Configure();
							_instance = LogManager.GetLogger("ERRORFileAppender");
						}
					}
				}

				return _instance;
			}
		}

		public static void ErrorFormat(this ILog self, Exception e, string msg, params object[] args)
		{
			self.Error( string.Format( msg, args ), e );
		}
	}
}