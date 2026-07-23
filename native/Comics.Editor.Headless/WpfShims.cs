// SDD sdd-comics-editor-v2.9 (обвязка): минимальный shim WPF-типов для компиляции
// линкованных моделей вне Windows. Используется только Point (PivotAnim.Pivot);
// остальные файлы содержат неиспользуемый `using System.Windows;`, которому
// достаточно существования namespace.

namespace System.Windows
{
	/// <summary>Headless-замена WPF MessageBox: сообщение уходит в stderr (UI-диалогов нет).</summary>
	public static class MessageBox
	{
		public static void Show(string messageBoxText, string caption = null)
		{
			Console.Error.WriteLine((caption != null ? caption + ": " : string.Empty) + messageBoxText);
		}
	}

	public struct Point
	{
		public double X { get; set; }
		public double Y { get; set; }

		public Point(double x, double y)
		{
			X = x;
			Y = y;
		}

		public override string ToString()
		{
			return X + ";" + Y;
		}
	}
}
