# Comics Editor v2.9

Flutter-приложение (Windows / macOS / Linux) вокруг существующего C#-редактора комиксов v2.8 — **без переписывания C#-кода**, только обвязка и реструктуризация папок.

- **Этап 1 — Windows**: полный WPF-редактор как есть, внутри Flutter-приложения (мост через MethodChannel; доделка interop — на Windows-машине, см. ниже).
- **Этап 2 — macOS/Linux**: Flutter-интерфейс из `design/comics-editor-maket-dart-v3` + headless-ядро `Comics.Editor.Headless` (.NET 10, self-contained) для реальных open/save.

Спецификация и история решений: `flows/sdd-comics-editor-v2.9/`.

## Структура

```
lib/                        Dart: main.dart (переключение по платформе)
  src/ui/                   UI из design/comics-editor-maket-dart-v3 (копия)
  src/bridge/               обвязка: core_client (NDJSON), models_mapping, wpf_editor_view
windows/                    Flutter runner + editor_plugin (C++ мост к WPF)
macos/ linux/               Flutter runner
native/                     C#-решение (перемещено из корня, код как есть)
  Comics.Editor/            WPF-редактор (net10.0-windows)
  Comics.Core/              серверная библиотека (net10.0; редактором не используется)
  Comics.Editor.Flutter/    обвязка: EditorHost (показ MainWindow), MethodChannelHandler
  Comics.Editor.Headless/   обвязка: NDJSON-хост (линкует не-UI исходники редактора)
  Utils/                    7za.exe, ImageMagick (Windows-бинарники)
tool/build_headless.sh|ps1  публикация headless-ядра (self-contained)
test/fixtures/sample.comics образец файла (из flutter_comics_viewer example)
```

## Сборка

Требования: Flutter ≥ 3.10; .NET 10 SDK (только на машине сборки); на macOS/Linux для операций с изображениями — ImageMagick (`brew install imagemagick` / `apt install imagemagick`).

### macOS / Linux

```bash
flutter pub get
tool/build_headless.sh        # публикует ядро + копирует в собранный бандл, если он есть
flutter run -d macos          # или -d linux
```

Открытие файла: Open → Browse… → путь к `.comics`/`.puzzle`. Ядро ищется по `COMICS_CORE_PATH`, затем в ресурсах бандла, затем в `native/Comics.Editor.Headless/publish/<rid>/` (dev-режим).

Проверка: `flutter test` (включая интеграционный round-trip open→save→reopen на `test/fixtures/sample.comics`), `dotnet build native/Comics.slnx`.

### Windows (этап 1 — чек-лист доделки)

Всё готово, кроме interop-слоя C++ → .NET (невозможно собрать/проверить на macOS). На Windows-машине (VS 2022 + .NET 10 SDK + Flutter):

1. `dotnet build native/Comics.slnx` — все 4 проекта должны собраться.
2. Реализовать в `windows/editor_plugin/editor_plugin.cpp` вызов .NET:
   - вариант A (рекомендуется): `hostfxr`/`nethost` → загрузка `Comics.Editor.Flutter.dll` (публикуется CMake-таргетом в `<build>/dotnet/`) → `MethodChannelHandler.HandleMethodCall(method, argsJson)`;
   - вариант B: C++/CLI-прослойка (как в эксперименте `libs/comics_editor/flutter_comics_editor`).
   - `create` → `EditorHost.ShowMainWindow()` — показывает полный WPF-редактор.
3. `flutter run -d windows` — до реализации interop Dart показывает заглушку с этой инструкцией (см. `lib/src/bridge/wpf_editor_view.dart`).
4. Следующий шаг (опционально): встраивание `ComicsControl` как PlatformView в окно Flutter вместо отдельного окна.

## Минорные фиксы C# (полный список)

Код не переписывался; для сборки под .NET 10 сделано только:

- `Comics.Editor/IWS/Utils/Logger.cs`, `Comics.Core/Utils/Logger.cs` — 2 строки: явный assembly/repository в вызовах log4net (в netstandard-сборке нет старых перегрузок).
- `Comics.Core`: `Compat/SystemWebCompat.cs` (новый shim `HostingEnvironment`/`HttpPostedFileBase` вместо удалённого System.Web); `Utils/PushManager.cs` исключён из компиляции (PushSharp существует только для net45), файл сохранён.
- csproj-файлы переписаны в SDK-style (net10.0 / net10.0-windows, PackageReference вместо packages.config); `Comics.sln` пересоздан как `Comics.slnx` (в старом был несуществующий Comics.Web).
- `Comics.Editor.Headless`: имя сборки — ровно `Comics.Editor` (data.json хранит `$type: "..., Comics.Editor"`).
