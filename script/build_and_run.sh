#!/usr/bin/env bash
set -euo pipefail

# 原生 Mac 构建与运行入口。临时签名不修改工程的 Team 设置。
MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Proxy Studio"
APP_BUNDLE="$ROOT_DIR/.build/run/Build/Products/Debug/$APP_NAME.app"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

case "$MODE" in
    run|--debug|--logs|--telemetry|--verify) ;;
    *) echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac

cd "$ROOT_DIR"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
xcodebuild -project ProxyStudio.xcodeproj -scheme ProxyStudioMac \
    -configuration Debug -destination 'platform=macOS' \
    -derivedDataPath "$ROOT_DIR/.build/run" \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual build

if [[ "$MODE" == "--debug" ]]; then
    exec lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
fi
/usr/bin/open -n "$APP_BUNDLE"
case "$MODE" in
    --logs) exec /usr/bin/log stream --info --style compact --predicate 'process == "Proxy Studio"' ;;
    --telemetry) exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.example.ProxyStudio"' ;;
    --verify)
        for _ in {1..20}; do
            if pgrep -x "$APP_NAME" >/dev/null; then exit 0; fi
            sleep 0.25
        done
        echo "Proxy Studio 未启动。" >&2
        exit 1
        ;;
esac
