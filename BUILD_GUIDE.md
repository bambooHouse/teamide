# TeamIDE Mac M5 打包指南

## 问题修复说明

我们已经修复了 Mac M5 芯片上快捷键失效的问题。问题根源是在最新提交中，electron-template 项目将应用程序菜单完全置空了，导致快捷键无法工作。

## 修复内容

1. 恢复了完整的菜单系统，包括标准的编辑菜单
2. 为 Mac 平台添加了原生快捷键支持（Command+C, Command+V 等）
3. 为其他平台添加了 Ctrl 快捷键支持
4. 更新了 package.json 以支持 arm64 架构打包

## 本地打包步骤

### 前置要求

- macOS 系统（推荐使用 M 系列芯片的机器）
- Go 1.20+
- Node.js 16+
- npm 7+

### 完整打包步骤

1. **清理旧文件**
```bash
rm -rf electron-template release darwin-amd64 darwin-arm64 teamide-html
```

2. **运行安装脚本准备 electron-template**
```bash
chmod +x ./desktop/install-electron-template.sh
./desktop/install-electron-template.sh
```

3. **克隆并构建前端**
```bash
git clone https://github.com/team-ide/teamide-html
cd teamide-html
npm install
npm run build
cd ..
```

4. **创建基础目录**
```bash
mkdir -p release/base/lib
cp -rf package.json release/
cp -rf README.md release/base/
cp -rf CHANGELOG.md release/base/CHANGELOG.md
cp -rf conf/release release/base/conf
cp -rf teamide-html/dist release/statics
```

5. **构建 Go 二进制文件（arm64）**
```bash
mkdir -p darwin-arm64
VERSION=$(node -p "require('./package.json').version")
CGO_ENABLED=1 GOARCH=arm64 go build -ldflags="-s -X teamide/pkg/base.version=${VERSION} -X main.buildFlags=--isServer" -o darwin-arm64/server .
CGO_ENABLED=1 GOARCH=arm64 go build -ldflags="-s -X teamide/pkg/base.version=${VERSION}" -o darwin-arm64/node teamide/pkg/node/main
```

6. **构建 amd64 二进制文件（用于通用支持）**
```bash
mkdir -p darwin-amd64
CGO_ENABLED=1 GOARCH=amd64 go build -ldflags="-s -X teamide/pkg/base.version=${VERSION} -X main.buildFlags=--isServer" -o darwin-amd64/server .
CGO_ENABLED=1 GOARCH=amd64 go build -ldflags="-s -X teamide/pkg/base.version=${VERSION}" -o darwin-amd64/node teamide/pkg/node/main
```

7. **复制二进制文件到 electron-template**
```bash
cp -rf release/statics ./electron-template/assets/server/statics
cp darwin-amd64/server ./electron-template/assets/server/server-darwin-amd64
cp darwin-arm64/server ./electron-template/assets/server/server-darwin-arm64
chmod +x ./electron-template/assets/server/server-darwin-amd64
chmod +x ./electron-template/assets/server/server-darwin-arm64
```

8. **构建 Electron 应用**
```bash
cd electron-template
npm install
npm run postinstall
npm run build
npm exec electron-builder -- --mac --arm64
```

9. **查找生成的文件**
```bash
# 构建完成后，dmg 文件将在以下位置：
ls -la electron-template/release/build/
```

## 使用预定义脚本

我们提供了完整的打包脚本 `build-mac-arm64.sh`，可以直接运行：

```bash
chmod +x build-mac-arm64.sh
./build-mac-arm64.sh
```

## 验证打包结果

打包完成后，在 `electron-template/release/build/` 目录中可以找到：
- `.dmg` 安装包文件
- `.zip` 压缩包文件

## 测试安装包

1. 在 Mac M5 芯片电脑上安装并运行
2. 测试复制粘贴功能是否正常工作
3. 确认其他快捷键功能正常

## 已知问题

- 如果需要代码签名，需要配置相应的签名证书
- 首次运行可能需要在系统设置中允许应用运行
