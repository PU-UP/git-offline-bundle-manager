#!/usr/bin/env bash
set -euo pipefail

ROOT=/work/develop_gitlab/slam-core      # ← 主仓根目录
OUT="$ROOT/bundles"
mkdir -p "$OUT"

echo ">>> bundling super-project"
cd "$ROOT"
git bundle create "$OUT/slam-core.bundle" --all

echo ">>> bundling submodules"
export OUT                                 # 让子进程拿得到
git submodule foreach --recursive '
  # 1) 把多层路径中的 / 全变 _
  bundle_name=$(echo "$name" | tr "/" "_").bundle
  echo "    → $bundle_name"
  # 2) 统一写到主仓 $OUT 目录
  git bundle create "$OUT/$bundle_name" --all
'
echo "✅ All bundles in $OUT"

