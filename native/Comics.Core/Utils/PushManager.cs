using Comics.DAL.Model;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using PushSharp.Apple;
using PushSharp.Core;
using PushSharp.Google;
using PushSharp.Windows;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security;
using System.Threading;
using System.Xml.Linq;

namespace IWS.Utils
{
	public static class PushManager
	{
		private static Timer _apnsFeedbackTimer = null;

		public static ApnsServiceBroker Apns { get; private set; }
		public static GcmServiceBroker Gcm { get; private set; }
		public static WnsServiceBroker Wns { get; private set; }

		public static void RegisterApns(bool isProduction, string certPath, string certPwd = "", bool feedback = true)
		{
			var env = isProduction ? ApnsConfiguration.ApnsServerEnvironment.Production : ApnsConfiguration.ApnsServerEnvironment.Sandbox;
			var config = new ApnsConfiguration(env, certPath, certPwd);
			Apns = new ApnsServiceBroker(config);
			Apns.OnNotificationFailed += NotificationFailed;
			Apns.OnNotificationSucceeded += NotificationSucceeded;
			Apns.Start();

			if (feedback)
				RegisterApnsFeedback(config);
		}

		private static void RegisterApnsFeedback(ApnsConfiguration config)
		{
			if (config.FeedbackIntervalMinutes == 0)
				return;

			var feedbackService = new FeedbackService(config);
			feedbackService.FeedbackReceived += (token, timestamp) => DeviceSubscriptionChanged(token, null, timestamp);

			if (_apnsFeedbackTimer != null)
			{
				_apnsFeedbackTimer.Dispose();
				_apnsFeedbackTimer = null;
			}

			_apnsFeedbackTimer = new Timer(x =>
			{
				try
				{
					feedbackService.Check();
				}
				catch (Exception ex)
				{
					LogError(ex);
				}
			}, null, TimeSpan.FromSeconds(10), TimeSpan.FromMinutes(config.FeedbackIntervalMinutes));
		}

		private static void RegisterGcm(string apiKey, string url)
		{
			var config = new GcmConfiguration(apiKey);
			if (!string.IsNullOrEmpty(url))
				config.GcmUrl = url;
			Gcm = new GcmServiceBroker(config);
			Gcm.OnNotificationFailed += NotificationFailed;
			Gcm.OnNotificationSucceeded += NotificationSucceeded;
			Gcm.Start();
		}

		public static void RegisterGcm(string apiKey)
		{
			RegisterGcm(apiKey, null);
		}

		public static void RegisterFcm(string apiKey)
		{
			RegisterGcm(apiKey, "https://fcm.googleapis.com/fcm/send");
		}

		public static void RegisterWns(string packageName, string packageSecurityIdentifier, string clientSecret)
		{
			Wns = new WnsServiceBroker(new WnsConfiguration(packageName, packageSecurityIdentifier, clientSecret));
			Wns.OnNotificationFailed += NotificationFailed;
			Wns.OnNotificationSucceeded += NotificationSucceeded;
			Wns.Start();
		}

		public static void SendApns(string token, string title, string text, string data, int badge = 0, string sound = "default")
		{
			var payload = string.Format("{{\"aps\":{{\"alert\":{{\"title\":{0},\"body\":{1}}},\"badge\":{2},\"sound\":\"{3}\"}},\"data\":{4}}}",
				JsonConvert.ToString(title), JsonConvert.ToString(text), badge, sound, data);
			var notif = new ApnsNotification
			{
				DeviceToken = token,
				Payload = JObject.Parse(payload)
			};
			// workaround for issue https://github.com/Redth/PushSharp/issues/713
			if (notif.IsDeviceRegistrationIdValid())
				Apns.QueueNotification(notif);
		}

		public static void SendGcm(string token, string data)
		{
			Gcm.QueueNotification(new GcmNotification
			{
				RegistrationIds = new List<string> { token },
				Data = JObject.Parse(data)
			});
		}

		public static void SendWns(string token, string title, string text, string data)
		{
			var payload = string.Format("<toast duration=\"long\" launch=\"toast://{2}\"><visual><binding template=\"ToastText02\"><text id=\"1\">{0}</text><text id=\"2\">{1}</text></binding></visual></toast>",
				SecurityElement.Escape(title), SecurityElement.Escape(text), SecurityElement.Escape(data));
			Wns.QueueNotification(new WnsToastNotification
			{
				ChannelUri = token,
				Payload = XElement.Parse(payload)
			});
		}

		public static void Send(PlatformTypes platform, string token, string title, string text, string data, string dataEmpty)
		{
			switch (platform)
			{
				case PlatformTypes.Android:
					SendGcm(token, data);
					break;
				case PlatformTypes.iOS:
					SendApns(token, title, text, dataEmpty);
					break;
				case PlatformTypes.WindowsPhone:
					SendWns(token, title, text, dataEmpty);
					break;
			}
		}

		public static void Stop()
		{
			if (Apns != null)
			{
				Apns.Stop();
				Apns = null;
			}
			if (_apnsFeedbackTimer != null)
			{
				_apnsFeedbackTimer.Dispose();
				_apnsFeedbackTimer = null;
			}
			if (Gcm != null)
			{
				Gcm.Stop();
				Gcm = null;
			}
			if (Wns != null)
			{
				Wns.Stop();
				Wns = null;
			}
		}

		private static void NotificationSucceeded(INotification notification)
		{
			// implement if needed
		}

		private static void DeviceSubscriptionChanged(string oldToken, string newToken, DateTime date)
		{
			Device.UpdatePushToken(oldToken, newToken);
		}

		private static void NotificationFailed(INotification notification, AggregateException exception)
		{
			exception.Handle(ex =>
			{
				if (ex is DeviceSubscriptionExpiredException)
				{
					var dsee = (DeviceSubscriptionExpiredException)ex;
					DeviceSubscriptionChanged(dsee.OldSubscriptionId, dsee.NewSubscriptionId, dsee.ExpiredAt);
				}
				else if (ex is GcmMulticastResultException)
				{
					var gmre = (GcmMulticastResultException)ex;
					foreach (var dsee in gmre.Failed.Values.OfType<DeviceSubscriptionExpiredException>())
						DeviceSubscriptionChanged(dsee.OldSubscriptionId, dsee.NewSubscriptionId, dsee.ExpiredAt);
				}
				else if (ex is ApnsNotificationException)
				{
					var ane = (ApnsNotificationException)ex;
					if (ane.ErrorStatusCode == ApnsNotificationErrorStatusCode.InvalidToken)
						DeviceSubscriptionChanged(ane.Notification.DeviceToken, null, DateTime.Now);
					else
						LogError(ex);
				}
				else
					LogError(ex);
				return true;
			});
		}

		private static void LogError(Exception ex)
		{
			Logger.Instance.Error("PushManager Exception", ex);
		}
	}
}
