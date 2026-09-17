#!/bin/bash

set -e

# Node 17+ 默认使用 OpenSSL 3，旧版 webpack(vue-cli) 依赖的 md4 哈希被禁用，
# 前端构建会报 ERR_OSSL_EVP_UNSUPPORTED，这里开启 legacy provider 兼容。
export NODE_OPTIONS=--openssl-legacy-provider

# TeamIDE Mac arm64 (M系列芯片) 打包脚本
VERSION=$(node -p "require('./package.json').version")
echo "开始打包 TeamIDE v${VERSION} for Mac arm64 (M系列芯片)"

# 清理旧的构建产物
echo "清理旧的构建产物..."
rm -rf electron-template release darwin-amd64 darwin-arm64 teamide-html

# 步骤 1: 准备 electron-template
echo "步骤 1: 准备 electron-template..."
chmod +x ./desktop/install-electron-template.sh
./desktop/install-electron-template.sh
mkdir -p electron-template/assets/server/lib
echo '依赖DLL、so库等' > electron-template/assets/server/lib/README.md

# electron-template 的 package.json 带有旧格式的 devEngines 字段，
# npm 11 会以 Invalid property "devEngines.node" 拒绝安装，这里移除之。
echo "修正 electron-template/package.json 的 devEngines 字段..."
node -e "const fs=require('fs');const f='electron-template/package.json';const p=JSON.parse(fs.readFileSync(f,'utf8'));if(p.devEngines){delete p.devEngines;fs.writeFileSync(f,JSON.stringify(p,null,2)+'\n');console.log('已移除 devEngines');}else{console.log('无 devEngines，跳过');}"

# 步骤 2: 克隆并构建前端
echo "步骤 2: 克隆并构建前端..."
git clone https://github.com/team-ide/teamide-html
cd teamide-html
npm install
npm run build
cd ..

# 步骤 3: 创建 release 目录
echo "步骤 3: 创建 release 目录..."
mkdir -p release
mkdir -p release/base
mkdir -p release/base/lib
echo '' > release/base/lib/README.md

cp -rf package.json release/
cp -rf RELEASE.md release/
cp -rf README.md release/base/
cp -rf CHANGELOG.md release/base/CHANGELOG.md
cp -rf conf/release release/base/conf

cp -rf release/base release/server-windows-amd64

cp -rf teamide-html/dist release/statics

echo '{"upload_url":""}' > release/release.json

# 步骤 4: 构建 Mac arm64 二进制文件
echo "步骤 4: 构建 Mac arm64 二进制文件..."
mkdir -p darwin-arm64
CGO_ENABLED=1 GOARCH=arm64 go build -ldflags="-s -X teamide/pkg/base.version=${VERSION} -X main.buildFlags=--isServer" -o darwin-arm64/server .
CGO_ENABLED=1 GOARCH=arm64 go build -ldflags="-s -X teamide/pkg/base.version=${VERSION}" -o darwin-arm64/node teamide/pkg/node/main

# 为了兼容性，也构建一个 amd64 版本（虽然我们主要打包 arm64）
echo "构建 Mac amd64 二进制文件（用于双架构支持）..."
mkdir -p darwin-amd64
CGO_ENABLED=1 GOARCH=amd64 go build -ldflags="-s -X teamide/pkg/base.version=${VERSION} -X main.buildFlags=--isServer" -o darwin-amd64/server .
CGO_ENABLED=1 GOARCH=amd64 go build -ldflags="-s -X teamide/pkg/base.version=${VERSION}" -o darwin-amd64/node teamide/pkg/node/main

# 步骤 5: 准备 electron 构建
echo "步骤 5: 准备 electron 构建..."
cp -rf release/statics ./electron-template/assets/server/statics
cp darwin-amd64/server ./electron-template/assets/server/server-darwin-amd64
cp darwin-arm64/server ./electron-template/assets/server/server-darwin-arm64

# 步骤 6: 构建服务端 zip 包
echo "步骤 6: 构建服务端 zip 包..."
mkdir -p release/server-darwin-amd64/lib

cp -rf release/statics release/server-darwin-amd64/statics
cp -rf conf/release release/server-darwin-amd64/conf
cp -rf docker/server.sh release/server-darwin-amd64/server.sh
chmod +x release/server-darwin-amd64/server.sh

cp -rf release/server-darwin-amd64 release/server-darwin-arm64

cp darwin-amd64/server release/server-darwin-amd64/teamide
cp darwin-arm64/server release/server-darwin-arm64/teamide

mv release/server-darwin-amd64 teamide-server-darwin-amd64-${VERSION}
zip -q -r teamide-server-darwin-amd64-${VERSION}.zip teamide-server-darwin-amd64-${VERSION}

mv release/server-darwin-arm64 teamide-server-darwin-arm64-${VERSION}
zip -q -r teamide-server-darwin-arm64-${VERSION}.zip teamide-server-darwin-arm64-${VERSION}

mkdir -p teamide-node-darwin-amd64-${VERSION}
cp darwin-amd64/node teamide-node-darwin-amd64-${VERSION}/node
zip -q -r teamide-node-darwin-amd64-${VERSION}.zip teamide-node-darwin-amd64-${VERSION}

mkdir -p teamide-node-darwin-arm64-${VERSION}
cp darwin-arm64/node teamide-node-darwin-arm64-${VERSION}/node
zip -q -r teamide-node-darwin-arm64-${VERSION}.zip teamide-node-darwin-arm64-${VERSION}

# 步骤 7: 构建 Electron 应用
echo "步骤 7: 构建 Electron 应用 (仅 arm64)..."
cd electron-template
chmod +x assets/server/server-darwin-amd64
chmod +x assets/server/server-darwin-arm64

# 检查 package.json
echo "检查 electron-template 的 package.json..."
cat package.json

# 安装依赖
echo "安装 npm 依赖..."
npm install
npm run postinstall
npm run build

# 只构建 arm64 的 dmg 包
echo "开始构建 Mac arm64 dmg 包..."
npm exec electron-builder -- --mac --arm64 -c.extraMetadata.main=./dist/main/main.js

echo "========================================"
echo "打包完成！"
echo "========================================"
echo ""
echo "生成的文件："
echo "1. 服务端 zip 包 (arm64): ../teamide-server-darwin-arm64-${VERSION}.zip"
echo "2. 服务端 zip 包 (amd64): ../teamide-server-darwin-amd64-${VERSION}.zip"
echo "3. Node zip 包 (arm64): ../teamide-node-darwin-arm64-${VERSION}.zip"
echo "4. Node zip 包 (amd64): ../teamide-node-darwin-amd64-${VERSION}.zip"
echo "5. Electron DMG 包: 查看 release 目录"
echo ""
echo "查找 DMG 文件..."
find ./release -name "*.dmg" 2>/dev/null || true
find ./dist -name "*.dmg" 2>/dev/null || true
