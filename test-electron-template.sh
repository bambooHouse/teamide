#!/bin/bash

set -e

echo "测试 electron-template 准备..."

# 清理旧文件
rm -rf electron-template

# 运行安装脚本
chmod +x ./desktop/install-electron-template.sh
./desktop/install-electron-template.sh

echo ""
echo "========================================"
echo "electron-template 准备完成！"
echo "========================================"
echo ""
echo "验证 main.ts 文件是否被正确修改："
ls -la electron-template/src/main/
echo ""
echo "main.ts 前 50 行："
head -50 electron-template/src/main/main.ts

echo ""
echo "验证 window.ts 文件："
ls -la electron-template/src/main/
echo ""
echo "检查是否导入了 setMainWindowReference："
grep -n "setMainWindowReference" electron-template/src/main/window.ts || echo "需要手动修改 window.ts"
