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
            using var document = string.IsNullOrWhiteSpace(argumentsJson)
                ? null
                : JsonDocument.Parse(argumentsJson);
            var args = document?.RootElement;
            int Pixel(string name)
            {
                var logical = args?.GetProperty(name).GetDouble() ?? 0;
                var ratio = args?.GetProperty("devicePixelRatio").GetDouble() ?? 1;
                return (int)Math.Round(logical * ratio);
            }
            switch (method)
            {
                case "create":
                    EditorHost.Create(
                        args!.Value.GetProperty("parentHwnd").GetInt64(),
                        Pixel("x"), Pixel("y"), Pixel("width"), Pixel("height"));
                    return JsonSerializer.Serialize(new { success = true });
                case "load":
                    EditorHost.Load(args!.Value.GetProperty("path").GetString()!);
                    return JsonSerializer.Serialize(new { success = true });
                case "setBounds":
                    EditorHost.SetBounds(Pixel("x"), Pixel("y"), Pixel("width"), Pixel("height"));
                    return JsonSerializer.Serialize(new { success = true });
                case "setVisible":
                    EditorHost.SetVisible(args!.Value.GetProperty("visible").GetBoolean());
                    return JsonSerializer.Serialize(new { success = true });
                case "setPosition":
                    EditorHost.SetPosition(args!.Value.GetProperty("position").GetDouble());
                    return JsonSerializer.Serialize(new { success = true });
                case "getPosition":
                    return JsonSerializer.Serialize(new { success = true, position = EditorHost.GetPosition() });
                case "setLanguage":
                    EditorHost.SetLanguage(args!.Value.GetProperty("index").GetInt32());
                    return JsonSerializer.Serialize(new { success = true });
                case "setSoundEnabled":
                    EditorHost.SetSoundEnabled(args!.Value.GetProperty("enabled").GetBoolean());
                    return JsonSerializer.Serialize(new { success = true });
                case "setPreview":
                    EditorHost.SetPreview(args!.Value.GetProperty("show").GetBoolean());
                    return JsonSerializer.Serialize(new { success = true });
                case "play":
                    EditorHost.Play();
                    return JsonSerializer.Serialize(new { success = true });
                case "pause":
                    EditorHost.Pause();
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
