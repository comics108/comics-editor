using System.Runtime.InteropServices;

namespace Comics.Editor.Flutter;

/// <summary>
/// Точка входа для hostfxr/nethost (вызывается из C++, windows/editor_plugin —
/// см. hostfxr_bootstrap.cpp). Строки — UTF-16 (char16_t* на стороне C++,
/// соответствует .NET string ABI напрямую, без доп. перекодирования).
///
/// sdd-comics-editor-v2.9-fixes2 (Track A): единственный потребитель —
/// EditorPlugin::HandleMethodCall (C++), который вызывает
/// hdt_load_assembly_and_get_function_pointer с EntryPoint'ами ниже.
/// </summary>
public static class NativeExports
{
    [UnmanagedCallersOnly(EntryPoint = "HandleMethodCall")]
    public static IntPtr HandleMethodCall(IntPtr methodPtr, IntPtr argsJsonPtr)
    {
        string result;
        try
        {
            string method = Marshal.PtrToStringUni(methodPtr) ?? string.Empty;
            string? argsJson = argsJsonPtr == IntPtr.Zero ? null : Marshal.PtrToStringUni(argsJsonPtr);
            result = MethodChannelHandler.HandleMethodCall(method, argsJson);
        }
        catch (Exception ex)
        {
            // MethodChannelHandler уже ловит свои исключения и сериализует их как
            // {"error": ..., "message": ...} — этот catch страхует от исключений
            // ВНЕ его try/catch (не должно происходить, но необработанное
            // исключение, пересекающее managed/native границу, роняет весь процесс).
            result = "{\"error\":\"" + ex.GetType().Name +
                      "\",\"message\":\"unmanaged boundary: " + ex.Message.Replace("\"", "'") + "\"}";
        }
        return Marshal.StringToHGlobalUni(result);
    }

    [UnmanagedCallersOnly(EntryPoint = "FreeResultString")]
    public static void FreeResultString(IntPtr ptr)
    {
        if (ptr != IntPtr.Zero) Marshal.FreeHGlobal(ptr);
    }
}
