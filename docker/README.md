# Docker Build

Контейнеризованная сборка Linux и Android для `comics-editor-v2.9` — использует те
же образы локально и на GitHub Actions, так что «работает у меня» и «работает в
CI» — одна и та же среда, а не две похожие. См. `flows/sdd-comics-editor-build/`
(requirements/specs/plan) за полной историей решений.

## Два раздельных процесса сборки

Docker Build **не заменяет** обычный CI — он существует параллельно с ним:

| | Native Build (`.github/workflows/build.yml`) | Docker Build (`.github/workflows/docker-build.yml`) |
|---|---|---|
| Когда запускается | каждый push/PR/`workflow_dispatch` | только `push` в `main`, ночью по расписанию, публикация релиза |
| Платформы | Windows, macOS, Linux, Android, iOS (6 job) | Linux, Android (2 job) |
| Среда | тулчейн ставится на раннере заново (`subosito/flutter-action`, `actions/setup-dotnet`, `actions/setup-java`) | тот же тулчейн, что и локально — Docker-образ с зафиксированными версиями |
| Цель | быстрая обратная связь на каждое изменение | воспроизводимость + публикуемые артефакты (retention 90 дней, прикрепление к GitHub Release) |
| Артефакты | `retention-days: 14`, имена `linux-build`/`android-build` | `retention-days: 90`, имена `linux-release-build`/`android-release-apk` |

Не трогает `release.yml` (fastlane/подпись/публикация в сторы — вне рамок).

## Почему только Linux и Android

| Платформа | Контейнеризуется? | Почему |
|---|---|---|
| Linux | Да | чистый Linux-тулчейн (GTK3/CMake/ninja/clang + .NET SDK) |
| Android | Да | Flutter + Gradle + JDK + Android SDK — всё работает в Linux-контейнере |
| Windows | Нет | WPF/CMake+MSVC требует реальной Windows; Windows-контейнеры существуют, но не решают «одинаково локально на macOS-машине разработчика и на раннере» — Docker Desktop for Mac в принципе не может запускать Windows-контейнеры |
| macOS | Нет | у Docker нет понятия «macOS-контейнер»; раннер и локальная машина разработчика — уже нативный macOS, так что среда и так одна и та же без контейнера |
| iOS | Нет | та же причина, что macOS |

## Быстрый старт

```bash
tool/docker-build.sh linux              # дефолтная verification-последовательность
tool/docker-build.sh android
tool/docker-build.sh linux bash         # интерактивный шелл для отладки CI-специфичных багов
tool/docker-build.sh linux <command>    # произвольная команда в том же окружении
```

Требуется только Docker (Desktop/Engine) — ничего из Flutter/.NET/Android SDK ставить
на хост не нужно. Скрипт сам собирает образ (переиспользует Docker layer cache при
повторных запусках) и монтирует репозиторий в `/workspace` внутри контейнера.

Локально (не в CI) контейнер запускается от текущего UID/GID (`--user $(id -u):$(id -g)`),
чтобы артефакты сборки на bind-mounted `/workspace` не становились root-owned.

## Известные ограничения этой машины (Apple Silicon)

- Официальный Flutter Linux SDK публикуется только под amd64 — `tool/docker-build.sh`
  жёстко фиксирует `--platform linux/amd64` для обоих образов.
- `--platform linux/amd64` на Apple Silicon работает **только** через Rosetta-эмуляцию
  Docker Desktop, не через qemu-user binfmt (qemu крашит `.NET`-рантайм на любой
  реальной JIT/threading-нагрузке — `qemu: uncaught target signal 6`). Включить:
  Docker Desktop → Settings → General → «Use Rosetta for x86_64/amd64 emulation on
  Apple Silicon» → Apply & Restart.
- Изредка Dart VM падает под Rosetta с `Unexpected EINTR errno` (`file_linux.cc`) —
  известное взаимодействие Dart VM/Rosetta (сигналы прерывают блокирующие файловые
  syscalls), не баг в этом репозитории. Транзиентно — повторный запуск обычно проходит.

## Файлы

- `linux-build.Dockerfile` — Ubuntu 24.04 + Flutter 3.44.6 + .NET SDK 10.0.302 + GTK3/CMake/ninja/clang.
- `android-build.Dockerfile` — Ubuntu 24.04 + Flutter 3.44.6 + Temurin JDK 17 + Android SDK
  (platform 35/36, build-tools 35.0.0/36.0.0, NDK 28.2.13676358, CMake 3.22.1 — версии
  35/NDK/CMake нужны не нашему коду, а дефолтам самого Flutter Gradle-плагина; без них
  Gradle скачивал бы их заново на каждом запуске).
- Оба образа содержат только тулчейн — исходники монтируются при `docker run`, не запекаются
  в образ, поэтому пересобирать образ нужно только при смене версий тулчейна.

## Локальный Gradle-кэш

`tool/docker-build.sh android` монтирует `.docker-cache/gradle/` (gitignored, рядом с
репозиторием) как `GRADLE_USER_HOME` — без этого Gradle/AGP/Kotlin-тулчейн выкачивался
бы заново на каждом запуске (контейнер `--rm`, `/tmp` не переживает между запусками).
