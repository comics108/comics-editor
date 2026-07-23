# Comics Editor v2.9

Flutter-приложение (Windows / macOS / Linux / **iOS / Android**) вокруг существующего C#-редактора комиксов v2.8 — **без переписывания C#-кода**, только обвязка и реструктуризация папок.

- **Windows**: полный WPF-редактор как есть, внутри Flutter-приложения (мост через MethodChannel; доделка interop — на Windows-машине, см. ниже).
- **macOS/Linux**: Flutter-интерфейс из `design/comics-editor-maket-dart-v3` + headless-ядро `Comics.Editor.Headless` (.NET 10, self-contained процесс) для реальных open/save.
- **iOS/Android** (iPhone/iPad/телефоны/планшеты): тот же Flutter-интерфейс (макет адаптивный) + то же C#-ядро, но как **NativeAOT-библиотека** `Comics.Editor.Native` через dart:ffi (процессы на iOS запрещены). Open — системный диалог (file_picker), Save — в песочницу приложения, Export — через системный диалог (Files/SAF).

Спецификации и история решений: `flows/sdd-comics-editor-v2.9/`, `flows/sdd-comics-editor-v2.9-android-ios/`.

## Структура

```
lib/                        Dart: main.dart (переключение по платформе)
  src/ui/                   UI из design/comics-editor-maket-dart-v3 (копия)
  src/bridge/               обвязка: comics_core (абстракция), core_client (NDJSON-процесс),
                            ffi_core (dart:ffi), models_mapping, documents, wpf_editor_view
windows/                    Flutter runner + editor_plugin (C++ мост к WPF)
macos/ linux/               Flutter runner
ios/ android/               Flutter runner (мобильные); ios/ComicsCore — vendored .a
native/                     C#-решение (перемещено из корня, код как есть)
  Comics.Editor/            WPF-редактор (net10.0-windows)
  Comics.Core/              серверная библиотека (net10.0; редактором не используется)
  Comics.Editor.Flutter/    обвязка: EditorHost (показ MainWindow), MethodChannelHandler
  Comics.Editor.Headless/   обвязка: NDJSON-хост (линкует не-UI исходники редактора)
  Comics.Editor.Native/     обвязка: NativeAOT C-ABI (comics_call/comics_free) для FFI
  Utils/                    7za.exe, ImageMagick (Windows-бинарники)
tool/build_headless.sh|ps1  публикация headless-ядра (self-contained, desktop)
tool/build_native.sh        публикация NativeAOT-библиотек (osx-тест | android | ios)
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

### iOS / Android

UI и Dart-обвязка готовы; ядро — NativeAOT-библиотека, собираемая `tool/build_native.sh`.
Проверка AOT-пути выполняется на хосте: `tool/build_native.sh osx` + `flutter test test/ffi_core_test.dart` (round-trip на sample.comics через dylib).

**Android** (`flutter build apk` / `flutter run`):

1. NativeAOT **не кросс-компилируется между ОС** — `.so` собирается на **Linux-машине** (или в Linux-контейнере с .NET 10 SDK и Android NDK):
   `export ANDROID_NDK_HOME=… && tool/build_native.sh android`
   → кладёт `libcomicscore.so` в `android/app/src/main/jniLibs/{arm64-v8a,x86_64}`.
2. Без `.so` приложение работает (UI-макет), Open/Save показывают «core unavailable».
3. Открытие из проводника: intent-filter уже в манифесте.

**iOS** (`flutter build ios`):

1. Один раз: `sudo dotnet workload install ios` (нужны права администратора).
2. `tool/build_native.sh ios` → `ios/ComicsCore/libComicsCore.a`.
3. После первой iOS-сборки (генерирует Podfile) добавить в target 'Runner':
   `pod 'ComicsCore', :path => 'ComicsCore'` (podspec уже лежит в `ios/ComicsCore/`, содержит `-force_load`).
4. FfiCore на iOS использует `DynamicLibrary.process()` — статическая линковка обязательна.
5. Типы документов `.comics`/`.puzzle` уже объявлены в Info.plist.

**Save/Export на мобильных**: Save пишет в `<Documents>/comics/` приложения (без диалогов; эти файлы видны в Open-диалоге как локальные документы), Export выгружает через системный диалог (Files/SAF).

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
