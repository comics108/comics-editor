#!/usr/bin/env bash
# sdd-comics-editor-build: локальный запуск Docker Build (те же образы, что CI).
#
# Использование:
#   tool/docker-build.sh <linux|android>              # дефолтная verification-последовательность
#   tool/docker-build.sh <linux|android> <command...>  # произвольная команда в том же окружении
#   tool/docker-build.sh linux bash                    # интерактивный шелл для отладки
#
# Пересобирает образ из docker/<target>-build.Dockerfile (использует Docker layer
# cache — быстро при повторных запусках), затем монтирует репозиторий в /workspace
# и выполняет команду. См. flows/sdd-comics-editor-build/ — requirements/specs/plan.

set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker не найден в PATH. Установите Docker Desktop: https://www.docker.com/products/docker-desktop/" >&2
  exit 1
fi

target="${1:-}"
case "$target" in
  linux|android) ;;
  *)
    echo "Usage: tool/docker-build.sh <linux|android> [command...]" >&2
    exit 1
    ;;
esac
shift

image="comics-editor-${target}-build:local"
# Оба образа зависят от Flutter Linux SDK, который публикуется только под amd64
# (см. flows/sdd-comics-editor-build/_status.md) — платформа зафиксирована явно,
# иначе `docker build` берёт архитектуру хоста и на Apple Silicon попадает в
# нерабочую qemu-binfmt эмуляцию вместо рабочей VM-эмуляции Docker Desktop.
platform=linux/amd64
docker build --platform "$platform" -f "docker/${target}-build.Dockerfile" -t "$image" docker

# Дефолтные verification-последовательности — дословно те же, что в build.yml
# (Native Build) и docker-build.yml (Docker Build); синхронизировать все три при
# изменении шагов сборки.
default_linux_cmd='flutter pub get \
  && dotnet build native/Comics.Editor.Headless/Comics.Editor.Headless.csproj -c Release \
  && flutter build linux --release \
  && tool/build_headless.sh \
  && flutter test test/widget_test.dart test/dart_io_core_test.dart test/core_client_test.dart'

default_android_cmd='flutter pub get \
  && flutter build apk --release \
  && flutter test test/widget_test.dart test/dart_io_core_test.dart'

user_flags=()
if [ -z "${CI:-}" ]; then
  # Локально (не в CI) — запускаем от текущего пользователя, чтобы артефакты
  # сборки на bind-mounted /workspace не становились root-owned на Linux-хостах.
  user_flags=(--user "$(id -u):$(id -g)")
fi

if [ "$#" -gt 0 ]; then
  exec docker run --rm --platform "$platform" -v "$(pwd):/workspace" -w /workspace "${user_flags[@]}" "$image" "$@"
fi

case "$target" in
  linux) cmd="$default_linux_cmd" ;;
  android) cmd="$default_android_cmd" ;;
esac
exec docker run --rm --platform "$platform" -v "$(pwd):/workspace" -w /workspace "${user_flags[@]}" "$image" bash -c "$cmd"
