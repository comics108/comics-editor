using System.Text.Json;

namespace Comics.Editor.Flutter;

/// <summary>
/// Обработчик вызовов MethodChannel `comics_editor` от Flutter.
/// Вызывается из C++-плагина (строки JSON через interop-слой).
/// </summary>
public static class MethodChannelHandler
{
    /// <param name="method">Имя метода MethodChannel.</param>
    /// <param name="argumentsJson">JSON-аргументы (может быть null).</param>
    /// <returns>JSON-результат.</returns>
    public static string HandleMethodCall(string method, string? argumentsJson)
    {
        try
        {
            switch (method)
            {
                case "create": // показать полный WPF-редактор (этап 1)
                    EditorHost.ShowMainWindow();
                    return JsonSerializer.Serialize(new { success = true });
                case "dispose":
                    EditorHost.Shutdown();
                    return JsonSerializer.Serialize(new { success = true });
                default:
                    return JsonSerializer.Serialize(new { error = "Method not implemented", method });
            }
        }
        catch (Exception ex)
        {
            return JsonSerializer.Serialize(new { error = ex.GetType().Name, message = ex.Message });
        }
    }
}
