#!/bin/bash

# 移至脚本目录
cd "$(dirname "$0")" || exit 1
echo "$(pwd)"
cd .. || exit 1

templateDir="./electron-template"
# 安装 electron-template

git clone https://github.com/team-ide/electron-template
rm -rf "$templateDir/.git"

# 复制 应用信息 package.json 到 release/app
echo 'cp package.json'
cp -rf package.json "$templateDir/release/app/package.json"

echo 'app package.json info'
cat "$templateDir/release/app/package.json"

# 复制 应用配置 config.ts 到 src/main
echo 'cp config.ts'
cp -rf desktop/config.ts "$templateDir/src/main/config.ts"

echo 'config.ts info'
cat "$templateDir/src/main/config.ts"

# 设置 应用 变量
productName='TeamIDE'
appId='com.teamide.desktop'
publisherName='TeamIDE'
publishProvider='github'
publishOwner='team-ide'
publishRepo='teamide'

echo 'set productName='$productName
echo 'set appId='$appId
echo 'set publisherName='$publisherName
echo 'set publishProvider='$publishProvider
echo 'set publishOwner='$publishOwner
echo 'set publishRepo='$publishRepo

# 使用 Node.js 脚本来安全地替换 package.json 中的占位符
cat > "$templateDir/replace-placeholders.js" << 'EOF'
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const productName = args[0];
const appId = args[1];
const publisherName = args[2];
const publishProvider = args[3];
const publishOwner = args[4];
const publishRepo = args[5];

const packageJsonPath = path.join(__dirname, 'package.json');
const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));

// 替换占位符
packageJson.build.productName = productName;
packageJson.build.appId = appId;
packageJson.build.win.publisherName = publisherName;
packageJson.build.publish = {
  provider: publishProvider,
  owner: publishOwner,
  repo: publishRepo
};

// 为 Mac arm64 支持添加架构配置
packageJson.build.mac.target = [
  {
    target: "zip",
    arch: ["x64", "arm64"]
  },
  {
    target: "dmg",
    arch: ["x64", "arm64"]
  }
];

// 保存修改后的文件
fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2));

console.log('package.json 已成功更新！');
EOF

# 设置包相关信息
echo 'replace placeholders in package.json'
cd "$templateDir" || exit 1
node replace-placeholders.js "$productName" "$appId" "$publisherName" "$publishProvider" "$publishOwner" "$publishRepo"
rm replace-placeholders.js
cd .. || exit 1

echo 'package.json info'
cat "$templateDir/package.json"

# 修复 Mac M5 芯片快捷键问题 - 恢复标准编辑菜单
echo 'Fixing menu issue for keyboard shortcuts...'
cat > "$templateDir/src/main/main.ts" << 'EOF'
/* eslint global-require: off, no-console: off, promise/always-return: off */
/**
 * This module executes inside of electron's main process. You can start
 * electron renderer process from here and communicate with the other processes
 * through IPC.
 *
 * When running `npm run build` or `npm run build:main`, this file is compiled to
 * `./src/main.js` using webpack. This gives us some performance wins.
 */
import { app, Menu, Tray, MenuItem, shell, BrowserWindow, MenuItemConstructorOptions } from 'electron';
import config from './config';
import { options } from './util';
import { startMainWindow, checkWindowHideOrShow, allWindowDestroy, refreshAllWindow } from './window';
import { stopServer, restartServer } from './server';
import { toAppUpdater, updaterDestroy } from './updater';
import log from 'electron-log';
log.info("app start")
// 忽略https证书相关错误，加在electron相关js文件里，有app的地方
app.commandLine.appendSwitch('ignore-certificate-errors')

// 构建标准菜单，支持复制粘贴等快捷键
class MenuBuilder {
  mainWindow: BrowserWindow | null = null;

  buildMenu(): Menu {
    const template =
      process.platform === 'darwin'
        ? this.buildDarwinTemplate()
        : this.buildDefaultTemplate();
    const menu = Menu.buildFromTemplate(template);
    Menu.setApplicationMenu(menu);
    return menu;
  }

  buildDarwinTemplate(): MenuItemConstructorOptions[] {
    const subMenuAbout: any = {
      label: 'TeamIDE',
      submenu: [
        {
          label: 'About TeamIDE',
          selector: 'orderFrontStandardAboutPanel:',
        },
        { type: 'separator' },
        { label: 'Services', submenu: [] },
        { type: 'separator' },
        {
          label: 'Hide TeamIDE',
          accelerator: 'Command+H',
          selector: 'hide:',
        },
        {
          label: 'Hide Others',
          accelerator: 'Command+Shift+H',
          selector: 'hideOtherApplications:',
        },
        { label: 'Show All', selector: 'unhideAllApplications:' },
        { type: 'separator' },
        {
          label: 'Quit',
          accelerator: 'Command+Q',
          click: () => {
            app.quit();
          },
        },
      ],
    };
    const subMenuEdit: any = {
      label: 'Edit',
      submenu: [
        { label: 'Undo', accelerator: 'Command+Z', selector: 'undo:' },
        { label: 'Redo', accelerator: 'Shift+Command+Z', selector: 'redo:' },
        { type: 'separator' },
        { label: 'Cut', accelerator: 'Command+X', selector: 'cut:' },
        { label: 'Copy', accelerator: 'Command+C', selector: 'copy:' },
        { label: 'Paste', accelerator: 'Command+V', selector: 'paste:' },
        {
          label: 'Select All',
          accelerator: 'Command+A',
          selector: 'selectAll:',
        },
      ],
    };
    const subMenuViewDev: MenuItemConstructorOptions = {
      label: 'View',
      submenu: [
        {
          label: 'Reload',
          accelerator: 'Command+R',
          click: () => {
            if (this.mainWindow) {
              this.mainWindow.webContents.reload();
            }
          },
        },
        {
          label: 'Toggle Full Screen',
          accelerator: 'Ctrl+Command+F',
          click: () => {
            if (this.mainWindow) {
              this.mainWindow.setFullScreen(!this.mainWindow.isFullScreen());
            }
          },
        },
        {
          label: 'Toggle Developer Tools',
          accelerator: 'Alt+Command+I',
          click: () => {
            if (this.mainWindow) {
              this.mainWindow.webContents.toggleDevTools();
            }
          },
        },
      ],
    };
    const subMenuViewProd: MenuItemConstructorOptions = {
      label: 'View',
      submenu: [
        {
          label: 'Toggle Full Screen',
          accelerator: 'Ctrl+Command+F',
          click: () => {
            if (this.mainWindow) {
              this.mainWindow.setFullScreen(!this.mainWindow.isFullScreen());
            }
          },
        },
      ],
    };
    const subMenuWindow: any = {
      label: 'Window',
      submenu: [
        {
          label: 'Minimize',
          accelerator: 'Command+M',
          selector: 'performMiniaturize:',
        },
        { label: 'Close', accelerator: 'Command+W', selector: 'performClose:' },
        { type: 'separator' },
        { label: 'Bring All to Front', selector: 'arrangeInFront:' },
      ],
    };
    const subMenuHelp: MenuItemConstructorOptions = {
      label: 'Help',
      submenu: [
        {
          label: 'Learn More',
          click() {
            shell.openExternal('https://github.com/team-ide/teamide');
          },
        },
      ],
    };
    const subMenuView =
      process.env.NODE_ENV === 'development' ||
      process.env.DEBUG_PROD === 'true'
        ? subMenuViewDev
        : subMenuViewProd;
    return [subMenuAbout, subMenuEdit, subMenuView, subMenuWindow, subMenuHelp];
  }

  buildDefaultTemplate() {
    const templateDefault = [
      {
        label: '&File',
        submenu: [
          {
            label: '&Close',
            accelerator: 'Ctrl+W',
            click: () => {
              if (this.mainWindow) {
                this.mainWindow.close();
              }
            },
          },
        ],
      },
      {
        label: '&Edit',
        submenu: [
          { label: 'Undo', accelerator: 'Ctrl+Z', role: 'undo' },
          { label: 'Redo', accelerator: 'Ctrl+Y', role: 'redo' },
          { type: 'separator' },
          { label: 'Cut', accelerator: 'Ctrl+X', role: 'cut' },
          { label: 'Copy', accelerator: 'Ctrl+C', role: 'copy' },
          { label: 'Paste', accelerator: 'Ctrl+V', role: 'paste' },
          { label: 'Select All', accelerator: 'Ctrl+A', role: 'selectAll' },
        ],
      },
      {
        label: '&View',
        submenu:
          process.env.NODE_ENV === 'development' ||
          process.env.DEBUG_PROD === 'true'
            ? [
                {
                  label: '&Reload',
                  accelerator: 'Ctrl+R',
                  click: () => {
                    if (this.mainWindow) {
                      this.mainWindow.webContents.reload();
                    }
                  },
                },
                {
                  label: 'Toggle &Full Screen',
                  accelerator: 'F11',
                  click: () => {
                    if (this.mainWindow) {
                      this.mainWindow.setFullScreen(
                        !this.mainWindow.isFullScreen()
                      );
                    }
                  },
                },
                {
                  label: 'Toggle &Developer Tools',
                  accelerator: 'Alt+Ctrl+I',
                  click: () => {
                    if (this.mainWindow) {
                      this.mainWindow.webContents.toggleDevTools();
                    }
                  },
                },
              ]
            : [
                {
                  label: 'Toggle &Full Screen',
                  accelerator: 'F11',
                  click: () => {
                    if (this.mainWindow) {
                      this.mainWindow.setFullScreen(
                        !this.mainWindow.isFullScreen()
                      );
                    }
                  },
                },
              ],
      },
      {
        label: 'Help',
        submenu: [
          {
            label: 'Learn More',
            click() {
              shell.openExternal('https://github.com/team-ide/teamide');
            },
          },
        ],
      },
    ];
    return templateDefault;
  }
}

// if (process.env.NODE_ENV === 'production') {
//   const sourceMapSupport = require('source-map-support');
//   sourceMapSupport.install();
// }
// if (isDebug) {
// require('electron-debug')();
// }
/**
 * Add event listeners...
 */
app.on('window-all-closed', () => {
  log.info("on window all closed")
  // Respect the OSX convention of having the application in memory even
  // after all windows have been closed
  if (config.window.hideWhenStart || config.window.hideWhenClose) {
    return
  }
  if (process.platform !== 'darwin') {
    destroyAll()
  }
});

let menuBuilder: MenuBuilder;

app
  .whenReady()
  .then(() => {
    log.info("on app ready")
    // 构建菜单
    menuBuilder = new MenuBuilder();
    menuBuilder.buildMenu();
    
    startMainWindow();
    app.on('activate', () => {
      log.info("on app activate")
      // On macOS it's common to re-create a window in the app when the
      // dock icon is clicked and there are no other windows open.
      startMainWindow();
    });
  })
  .catch(log.info);
export let tray: Tray | null = null;
export const appMenu: any = {
  refreshMenu: {
    id: "refreshMenu",
    label: '刷新',
    visible: true,
    enabled: true,
    click: function () {
      refreshAllWindow()
    },
  },
  stopServerMenu: {
    id: "stopServerMenu",
    label: '关闭服务',
    visible: false,
    enabled: true,
    click: function () {
      stopServer()
    },
  },
  startServerMenu: {
    id: "startServerMenu",
    label: '启动服务',
    visible: false,
    enabled: true,
    click: function () {
      restartServer()
    },
  },
  restartServerMenu: {
    id: "restartServerMenu",
    label: '重启服务',
    visible: false,
    enabled: true,
    click: function () {
      restartServer()
    },
  },
  updaterMenu: {
    id: "updaterMenu",
    label: '检查更新',
    visible: true,
    enabled: true,
    click: function () {
      toAppUpdater()
    },
  },
  quitMenu: {
    id: "quitMenu",
    label: '退出',
    visible: true,
    enabled: true,
    click: function () {
      destroyAll()
    },
  },
}
let trayImage: string = ""
if (process.platform === 'darwin') {
  trayImage = (options.icon16Path)
} else {
  trayImage = (options.icon64Path)
}
let menus = [];
menus.push(appMenu.refreshMenu)
menus.push(appMenu.startServerMenu)
menus.push(appMenu.stopServerMenu)
menus.push(appMenu.restartServerMenu)
menus.push(appMenu.updaterMenu)
menus.push(appMenu.quitMenu)
export const contextMenu = Menu.buildFromTemplate(menus)
export const getMenuItemById = (id: string): MenuItem | null => {
  if (contextMenu == null) {
    return null
  }
  let find = null
  contextMenu.items.forEach((one) => {
    if (one.id == id) {
      find = one
    }
  })
  return find
}
app.on('ready', async () => {
  log.info("on app ready")
  tray = new Tray(trayImage)
  tray.setToolTip(config.tray.toolTip)
  if (process.platform === `darwin`) {
    //显示程序页面
    tray.on('mouse-up', checkWindowHideOrShow)
  } else {
    //显示程序页面
    tray.on('click', checkWindowHideOrShow)
  }
  tray.setContextMenu(contextMenu)
})
// 只有显式调用quit才退出系统，区分MAC系统程序坞退出和点击X关闭退出
app.on('before-quit', () => {
  log.info('before-quit');
  options.willQuitApp = true
  destroyAll()
});
let destroyAllEd = false
export const destroyAll = () => {
  if (destroyAllEd) {
    return
  }
  destroyAllEd = true
  log.info("destroy all start")
  options.isStopped = true
  try {
    allWindowDestroy()
  } catch (error) {
    log.error("all window error:", error)
  }
  try {
    stopServer()
  } catch (error) {
    log.error("stop server error:", error)
  }
  try {
    if (tray != null) {
      tray.destroy()
    }
  } catch (error) {
    log.error("tray destroy error:", error)
  }
  try {
    updaterDestroy()
  } catch (error) {
    log.error("updater destroy error:", error)
  }
  try {
    if (app != null) {
      app.quit()
    }
  } catch (error) {
    log.error("app quit error:", error)
  }
  log.info("destroy all end")
}

// 导出一个函数来设置主窗口引用
export const setMainWindowReference = (win: BrowserWindow) => {
  if (menuBuilder) {
    menuBuilder.mainWindow = win;
  }
};
EOF

# 同时需要修改 window.ts，确保主窗口创建后设置菜单的引用
echo 'Fixing window.ts to set main window reference...'
if [ -f "$templateDir/src/main/window.ts" ]; then
  # 备份原始文件
  cp "$templateDir/src/main/window.ts" "$templateDir/src/main/window.ts.backup"
  
  # 创建一个 Node.js 脚本来修改 window.ts
  cat > "$templateDir/fix-window.js" << 'EOF'
const fs = require('fs');
const path = require('path');

const windowTsPath = path.join(__dirname, 'src/main/window.ts');
let content = fs.readFileSync(windowTsPath, 'utf8');

// 1. 添加 setMainWindowReference 导入
content = content.replace(
  'import { destroyAll } from \'./main\';',
  'import { destroyAll, setMainWindowReference } from \'./main\';'
);

// 2. 读取内容并找到合适的位置插入
const lines = content.split('\n');
let depth = 0;
let inWindow = false;

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  if (line.includes('mainWindow = new BrowserWindow({')) {
    inWindow = true;
    depth = 1;
  } else if (inWindow) {
    if (line.includes('{')) depth++;
    if (line.includes('}')) {
      depth--;
      if (depth === 0) {
        // 在这一行之后插入
        lines.splice(i + 1, 0, '    // 设置主窗口引用到菜单');
        lines.splice(i + 2, 0, '    setMainWindowReference(mainWindow);');
        break;
      }
    }
  }
}

content = lines.join('\n');

fs.writeFileSync(windowTsPath, content);
console.log('window.ts 已成功更新！');
EOF

  # 运行修复脚本
  cd "$templateDir" || exit 1
  node fix-window.js
  rm fix-window.js
  cd .. || exit 1
fi

echo 'Menu fix complete! Keyboard shortcuts like Ctrl+C/Ctrl+V and Command+C/Command+V should now work properly on all platforms including Mac M5.'
