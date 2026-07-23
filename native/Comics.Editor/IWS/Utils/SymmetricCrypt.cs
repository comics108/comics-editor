using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;

namespace IWS.Utils
{
	public static class SymmetricCrypt
	{
		private static string _salt = "ht5D0Z_salt";
		private static string _passw = "V,1l&<fx]E863.-8";

		static string alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

		private static byte[] Decode(string text)
		{
			text = text ?? string.Empty;
			byte[] buffer = new byte[text.Length / 2];
			for (int i = 0; i < (buffer.Length * 2); i += 2)
				buffer[i / 2] = (byte)((alphabet.IndexOf( text[i] ) * alphabet.Length) + alphabet.IndexOf( text[i + 1] ));
			return buffer;
		}

		private static string Encode(byte[] bytes)
		{
			if ((bytes == null) || (bytes.Length == 0))
				return string.Empty;

			var builder = new StringBuilder();
			for (int i = 0; i < bytes.Length; i++)
			{
				builder.Append( alphabet[bytes[i] / alphabet.Length] );
				builder.Append( alphabet[bytes[i] % alphabet.Length] );
			}
			return builder.ToString();
		}

		public static byte[] EncryptData(byte[] data)
		{
			byte[] salt = Encoding.ASCII.GetBytes( _salt );
			byte[] res;

			var key = new Rfc2898DeriveBytes( _passw, salt );
			var alg = new RijndaelManaged();
			alg.BlockSize = 128;
			alg.FeedbackSize = 128;

			alg.Key = key.GetBytes( alg.BlockSize / 8 );
			alg.IV = key.GetBytes( alg.BlockSize / 8 );

			using (var memStream = new MemoryStream())
			{
				using (CryptoStream encrypt = new CryptoStream( memStream, alg.CreateEncryptor(), CryptoStreamMode.Write ))
				{
					encrypt.Write( data, 0, data.Length );
					encrypt.FlushFinalBlock();
				}
				res = memStream.ToArray();
			}

			return res;
		}

		public static byte[] DecryptData(byte[] data)
		{
			byte[] salt = Encoding.ASCII.GetBytes( _salt );
			byte[] res;

			var key = new Rfc2898DeriveBytes( _passw, salt );
			var alg = new RijndaelManaged();
			alg.BlockSize = 128;
			alg.FeedbackSize = 128;

			alg.Key = key.GetBytes( alg.BlockSize / 8 );
			alg.IV = key.GetBytes( alg.BlockSize / 8 );

			using (MemoryStream memStream = new MemoryStream())
			{
				using (CryptoStream decrypt = new CryptoStream( memStream, alg.CreateDecryptor(), CryptoStreamMode.Write ))
				{
					decrypt.Write( data, 0, data.Length );
					decrypt.Flush();
				}
				res = memStream.ToArray();
			}

			return res;
		}

		public static string EncryptString(string text)
		{
			var data = Encoding.ASCII.GetBytes( text );
			var res = EncryptData( data );
			return Encode( res ).Trim();
		}

		public static string DecryptString(string text)
		{
			var data = Decode( text );
			var res = DecryptData( data );
			return Encoding.ASCII.GetString( res ).Trim();
		}

		public static KeyValuePair<string, string> GeneratePasswordHash(string password)
		{
			var salt = Guid.NewGuid().ToString("N") + Guid.NewGuid().ToString("N");
			var hash = HashPassword(password, salt);
			return new KeyValuePair<string, string>(hash, salt);
		}

		public static bool IsValidPassword(string password, string hash, string salt)
		{
			return hash == HashPassword(password, salt);
		}

		private static string HashPassword(string password, string salt)
		{
			return GetHash(password + salt);
		}

		private static string GetHash(string text)
		{
			var bytes = Encoding.Unicode.GetBytes(text);
			var sha512 = new SHA512Managed();
			return string.Join(string.Empty, sha512.ComputeHash(bytes).Select(x => string.Format("{0:x2}", x)));
		}
	}
}