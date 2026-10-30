# EcoHub for OHOS

[![Release](https://img.shields.io/github/v/release/fe-spark/EcoHub-for-OHOS)](https://github.com/fe-spark/EcoHub-for-OHOS/releases)
[![Download HAP](https://img.shields.io/badge/Download-.hap-orange?logo=huawei&logoColor=white)](https://github.com/fe-spark/EcoHub-for-OHOS/releases/latest)
[![OpenHarmony](https://img.shields.io/badge/OpenHarmony-API%2012+-blue)](https://www.openharmony.cn/)

[EcoHub](https://github.com/fe-spark/EcoHub) 的 OpenHarmony / HarmonyOS 原生客户端。

> **提示**：本仓库是 EcoHub 的纯客户端应用，**本身不提供、不存储任何影视资源**。安装后需要配置并接入 EcoHub 软件源（服务端）方可正常浏览与观影。
> 
> 相关项目：[EcoHub 主仓库（服务端 + Web）](https://github.com/fe-spark/EcoHub) · [EcoHub for Android](https://github.com/fe-spark/EcoHub-for-Android)

<div align="center">

<img src="./preview.jpg" alt="EcoHub for OHOS 截图" width="360" />

</div>

---

## 📥 下载安装

- 🚀 **[下载最新版本 HAP (Releases Latest)](https://github.com/fe-spark/EcoHub-for-OHOS/releases/latest)**
- 📜 **[查看所有历史版本与更新日志](https://github.com/fe-spark/EcoHub-for-OHOS/releases)**

---

## 📡 软件源说明

客户端所有影视列表、分类、搜索、播放地址均由 **EcoHub 软件源** 提供。

### 1. 软件源怎么来？

- **自建部署（推荐）**  
  按照 [EcoHub 部署指南](https://github.com/fe-spark/EcoHub/blob/main/docs/README-Deploy.md) 在你的服务器上部署 EcoHub 服务端。  
  部署成功后，在管理后台「工作台」点击「订阅地址」即可获取客户端订阅源：
  ```
  http://<你的服务器IP或域名>:3000/api/provide/app
  ```
  *(若配置了 HTTPS 或反向代理，格式为 `https://<你的域名>/api/provide/app`，亦兼容原 `/api` 路径)*。在管理后台完成影视数据采集后，客户端即可直接同步。

- **使用公共源 / 他人分享源**  
  如果你有朋友已经部署了 EcoHub 站点，或使用社区公开的 EcoHub 节点，可以直接获取其软件源地址填入（例如官方演示源 `https://eco.fe-spark.cn/api/provide/app`）。

### 2. 如何在 App 中配置？

1. 打开 App，首次进入或未连接时会自动弹出 **软件源配置** 界面；
2. 输入软件源地址（如 `http://<服务器IP或域名>:3000` 或复制后台完整的 `/api/provide/app` 订阅源，未填协议头会自动补齐 `https://`；若站点开启了私有化访问，在地址末尾追加 `?key=您的密钥`）；
3. 点击 **开始观影** / **重新接入**，App 会自动测试与服务端的连通性（请求 `/api/provide/app` 接口）；
4. 校验通过后即可进入首页观影。后续可在「我的」或设置中管理/切换历史软件源。

---

## 推荐

### 服务器

| 服务商 | 说明 | 链接 |
| --- | --- | --- |
| CloudCone | 1. 演示站点所用服务商<br>2. 高性价比 VPS，磁盘 I/O 不受限 | [前往选购](https://app.cloudcone.com/?ref=14393) |

### 网络服务

| 服务商 | 特点 / 价格 | 链接 |
| --- | --- | --- |
| 良心云 | 低至 2 元/月 <br>新用户注册即获体验流量 | [前往注册](https://xn--9kqz23b19z.com/#/register?code=xAmvfdic) |
| 赔钱机场 | 低至 1.5 元/月 <br>适合高流量与备用需求 | [前往注册](https://xn--mes358aby2apfg.com/register?code=FA4xlzHD&cover=sfw) |
| DOVE |  | [前往注册](https://dovee.cc/a.php?asbcbO1PCgTx2JM66) |

---
## 💡 开发避坑指南（屏幕旋转与渲染性能最佳实践）

### 🚨 典型问题：手机旋转卡出系统桌面壁纸、延迟后才变全屏

#### 1. 现象描述
在控制中心关闭系统旋转锁定后，手机在应用内进行横竖屏旋转时，应用画面被卡在旧尺寸的正方形区域（如 `727×727`），其余未铺满区域直接**卡出系统底层的桌面壁纸**，持续约 300~500ms 后才突然展开为全屏。
> **特征**：数据加载中（仅 Loading 指示器）时旋转完全正常顺滑，一旦影视列表加载完成并渲染海报后，旋转必定卡出桌面背景。

#### 2. 原因剖析
1. **页面根节点严禁挂载 `.renderGroup(true)` 与根级 `.clip(true)`**：
   - ArkUI 的 `renderGroup(true)` 会强制将整页所有子组件渲染到一块**离屏纹理缓冲区（Offscreen Buffer）**。
   - 在系统窗口旋转转场动画期间，ArkUI **不会逐帧重绘/重建这个全屏离屏纹理**，而是直接复用旧尺寸纹理进行旋转变换；若同时配合根级 `.clip(true)`，超出旧尺寸的部分被硬件硬截断，导致多余区域透明，直接漏出下层的 Launcher 桌面壁纸；直到动画结束、离屏缓存失效后才重新测量重绘成全屏。
2. **卡片组件严禁挂载全局隐式动画 `.animation()`**：
   - 在 `FilmCard` 外层挂载 `.animation()` 会捕获组件的所有属性变更。旋转时断点宽度 `WINDOW_WIDTH` 变化，触发所有 `FilmRow` 内成百上千个卡片的 `cardWidth` 同步突变。
   - 这导致上百张海报同时启动 `120ms` 宽度插值动画，瞬间阻塞 UI 线程，导致应用无法在垂直同步周期内及时向 WMS 提交新方向的画面 Buffer，最终触发系统的**旋转转场超时兜底**（强制以旧画面 Buffer 旋转，未铺满区域透出壁纸）。
3. **窗口尺寸监听 `on('windowSizeChange')` 严禁同步发起跨进程 IPC**：
   - `windowSizeChange` 触发时正值旋转过渡首帧的关键期，如果在回调中同步调用 `win.getWindowAvoidArea()`（跨进程 IPC 调用），会进一步加剧主线程卡顿。避让区必须通过独立的 `avoidAreaChange` 监听负责。
4. **列表项慎用实时毛玻璃 `.backdropBlur`**：
   - 在大批量渲染的列表或横向滚动胶囊上批量使用 `backdropBlur`，会导致旋转重绘时 GPU 需频繁执行多通道离屏模糊 pass，严重争抢图形资源。

#### 3. 规范要求（防错准则）
- ❌ **禁止在任何页面根容器上使用 `.renderGroup(true)` 和根级 `.clip(true)`**。
- ❌ **禁止在列表卡片根节点上挂载全局 `.animation()`**。按压缩放等局部交互动效必须在 `onTouch` 中使用 `this.getUIContext().animateTo` 显式驱动。
- ❌ **禁止在 `windowSizeChange` 中同步调用 `getWindowAvoidArea`**，尺寸回调只负责更新尺寸与断点，避免主线程 IPC 阻塞。
- ❌ **避免在滚动列表项中滥用 `backdropBlur`**，尽量使用半透明纯色背景替代。
- ✅ **保持底层纯色兜底**：在 `WindowBar.applyBarColors()` 中始终保证 `target.setWindowBackgroundColor(AppTheme.BG)`，确保窗口层与页面底色始终一致。

### 🎬 播放器与分栏模式规范

#### 1. 规范设计
- **横屏保持分栏（`splitPlay`）**：在横屏模式下，播放详情页默认保持 **7:5 分栏模式**（左侧视频流，右侧剧集选集与相关推荐），**不要在横屏时强行自动全屏**，为用户留出横向边看边选集的交互空间。
- **全屏显式触发与退出**：
  - 仅在用户主动点击全屏按钮时才进入沉浸式全屏；
  - 进入全屏使用 `window.Orientation.USER_ROTATION_LANDSCAPE`，退出全屏恢复系统自动旋转策略 `AUTO_ROTATION_RESTRICTED`，使退出全屏后在横屏下自然回落至 7:5 分栏，竖屏下自然回落至半屏。
- **播放器比例与防拉伸规范**：
  - `VideoPlayer` 内维护容器宽高的 `playerW / playerH` 必须声明为 `@State` 响应式状态，在 `.onAreaChange` 尺寸变更时自动下发最新的 `containerWidth / containerHeight` 给 `PlayerVideoLayer`。
  - `PlayerVideoLayer` 在自身 `onAreaChange` 与父级传参双重保底下，实时根据 `videoRatio` 与 `containerRatio` 计算 `XComponent` 的适应比例（FIT 模式），杜绝退化为 100%×100% 导致画面随分栏/横竖屏被强行拉伸变扁。
  - 播放器与视频渲染层严禁使用 `.clip(true)`。
  - **宽屏分栏判定使用同步断点**：`isWideScreen()` 必须直接依赖 `@StorageLink` 绑定的 `WINDOW_WIDTH / WINDOW_HEIGHT`，**严禁使用异步 `onAreaChange` 回调赋值的临时 `@State` 变量**，否则在横转竖时第一帧会使用横屏分栏旧尺寸排版（导致视频被压缩在 210vp 狭窄区域，高度仅 118vp），下一帧才恢复 202.5vp，产生视觉上“高度从小变大”的二阶段跳变。
---

## 🛠️ 本地开发

使用 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 打开本工程目录进行调试与打包构建。

---

## 📄 开源许可

本项目遵循 [PolyForm Noncommercial 1.0.0](https://github.com/fe-spark/EcoHub/blob/main/LICENSE) 协议。
