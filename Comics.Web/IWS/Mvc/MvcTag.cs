using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Web;
using System.Web.Mvc;

namespace IWS.Mvc
{
	public class MvcTag : IDisposable
	{
		private bool _disposed;
		private readonly ViewContext _viewContext;
		private readonly TextWriter _writer;
		private readonly string _tagName;

		public MvcTag(ViewContext viewContext, string tagName)
		{
			if (viewContext == null)
				throw new ArgumentNullException("viewContext");
			if (string.IsNullOrEmpty(tagName))
				throw new ArgumentNullException("tagName");

			_viewContext = viewContext;
			_writer = viewContext.Writer;
			_tagName = tagName.Trim();
			if (_tagName.ToLower() == "form")
				throw new ArgumentOutOfRangeException("tagName", "Use MvcForm for a form tag.");
		}

		public void Dispose()
		{
			if (!_disposed)
			{
				_disposed = true;
				_writer.Write("</" + _tagName + ">");
			}
		}
	}
}