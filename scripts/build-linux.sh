#!/usr/bin/env bash
# Ubuntu/Linux 一键打包脚本：构建前端 -> 嵌入后端 -> 输出 bin/sub2api
# 使用：在仓库根目录执行 `bash scripts/build-linux.sh`
# 依赖：Go 1.26+、Node 20+、pnpm

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

VERSION="$(tr -d '\r\n' < backend/cmd/server/VERSION)"
OUTPUT_DIR="$REPO_ROOT/bin"
OUTPUT_BIN="$OUTPUT_DIR/sub2api"

echo "==> Repo:    $REPO_ROOT"
echo "==> Version: $VERSION"
echo "==> Output:  $OUTPUT_BIN"

echo "==> [1/3] Installing frontend deps (pnpm install --frozen-lockfile)"
# CI=true 让 pnpm 在非交互（无 TTY）环境下自动确认操作
# NPM_REGISTRY 可覆盖 registry，国内可设为 https://registry.npmmirror.com/
NPM_REGISTRY="${NPM_REGISTRY:-}"
PNPM_REGISTRY_FLAG=()
if [ -n "$NPM_REGISTRY" ]; then
    echo "    using registry: $NPM_REGISTRY"
    PNPM_REGISTRY_FLAG=(--registry "$NPM_REGISTRY")
fi
CI=true pnpm --dir frontend install --frozen-lockfile "${PNPM_REGISTRY_FLAG[@]}"

echo "==> [2/3] Building frontend (产出到 backend/internal/web/dist)"
pnpm --dir frontend run build

echo "==> [3/3] Building backend with embedded frontend (-tags embed)"
mkdir -p "$OUTPUT_DIR"
cd backend
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build \
        -tags embed \
        -trimpath \
        -ldflags "-s -w -X main.Version=$VERSION" \
        -o "$OUTPUT_BIN" \
        ./cmd/server

echo
echo "==> Done. Binary:"
ls -lh "$OUTPUT_BIN"
echo
echo "Deploy:"
echo "  scp $OUTPUT_BIN user@host:/path/to/sub2api"
echo "  # 远端：systemctl restart sub2api（或你的进程管理方式）"
