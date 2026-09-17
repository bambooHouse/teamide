# Mac M5 芯片快捷键问题修复方案

## 问题描述
在 Mac M5 芯片上运行 TeamIDE 的官方 dmg 包时，常见的键盘快捷键（如 ctrl+C、ctrl+V、Command+C、Command+V 等）无法正常工作。

## 问题根源
通过分析代码发现，在最新的 electron-template 仓库提交（`4b2654b1686e4d35f10d5ca964df13c3b5615a09`）中，团队将应用程序菜单完全置空了，这导致了快捷键功能失效。

## 修复方案

### 1. 已修改的文件
`/Users/liss/github/teamide/desktop/install-electron-template.sh`

### 2. 修复内容
该脚本在克隆 electron-template 后会自动：
- 替换 `main.ts` 文件，恢复完整的菜单系统
- 为 Mac 平台（darwin）提供标准的编辑菜单，支持 Command+C、Command+V 等快捷键
- 为 Windows/Linux 平台提供标准的编辑菜单，支持 Ctrl+C、Ctrl+V 等快捷键
- 修改 `window.ts` 文件，确保主窗口引用正确传递给菜单系统

### 3. 菜单包含的功能
- **Mac 平台**:
  - TeamIDE 菜单（关于、隐藏、退出等）
  - Edit 菜单（撤销、重做、剪切、复制、粘贴、全选）
  - View 菜单（刷新、全屏、开发者工具）
  - Window 菜单（最小化、关闭）
  - Help 菜单
  
- **Windows/Linux 平台**:
  - File 菜单
  - Edit 菜单（撤销、重做、剪切、复制、粘贴、全选）
  - View 菜单
  - Help 菜单

## 使用方法

### 重新构建应用
1. 确保在项目根目录
2. 正常运行发布构建流程，新构建的应用将包含修复

### 验证修复
构建完成后，在 Mac M5 芯片上运行新的 dmg 包，测试以下快捷键是否正常工作：
- 复制: Command+C (Mac) / Ctrl+C (其他平台)
- 粘贴: Command+V (Mac) / Ctrl+V (其他平台)
- 剪切: Command+X (Mac) / Ctrl+X (其他平台)
- 撤销: Command+Z (Mac) / Ctrl+Z (其他平台)
- 重做: Shift+Command+Z (Mac) / Ctrl+Y (其他平台)
- 全选: Command+A (Mac) / Ctrl+A (其他平台)

## 技术细节

### 关键修改
1. **恢复菜单系统**: 移除了将菜单置空的代码
2. **使用 MenuBuilder 类**: 重新实现了菜单构建逻辑
3. **平台适配**:
   - Mac 平台使用 `selector` 确保原生体验
   - 其他平台使用 `role` 确保兼容性
4. **窗口引用传递**: 添加 `setMainWindowReference` 函数确保菜单能正确访问主窗口

### 向后兼容性
- 保持了原有的托盘菜单和其他功能
- 不影响其他已有的功能特性
- 可以安全地回滚到原始代码

## 总结
这个修复方案通过恢复标准的应用程序菜单系统，解决了 Mac M5 芯片上快捷键失效的问题。该方案不仅解决了快捷键问题，还为所有平台提供了更完整的菜单支持和更好的用户体验。
