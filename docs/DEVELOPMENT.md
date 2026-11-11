# 开发指南

本文只有中文版。

## 环境与构建

使用 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 打开本工程目录，进行调试与打包构建。

工程面向 HarmonyOS，兼容 SDK 为 `5.0.1(13)`，目标 SDK 为 `6.1.1(24)`，见 `build-profile.json5`。

## 屏幕旋转与渲染

### 问题现象

关闭系统旋转锁定后，在应用内进行横竖屏旋转时，窗口可能仍停留在旋转前的尺寸，未铺满的区域会露出系统桌面壁纸。该问题在首页影视列表已渲染海报后更容易出现；仅显示加载指示器时通常不明显。

### 原因

旋转过程中，窗口尺寸与规避区会连续变化，并写入 `AppStorage`（如 `WINDOW_WIDTH`、`WIDTH_BP`、`SAFE_INSET_LEFT`、`SAFE_INSET_RIGHT`）。若多个列表子组件各自使用 `@StorageLink` 订阅这些键，会在同一帧内触发大量重绘，使新方向的画面无法及时提交。

若在每次 `avoidAreaChange`、`windowSizeChange` 回调中同步调用 `getWindowAvoidArea`，会在转场期间增加跨进程查询。

播放器使用 `XComponentType.SURFACE`。若仅依据延迟到达的 `onAreaChange` 计算结果为 `XComponent` 指定宽高，窗口已被拉伸时图层尺寸可能仍是旧值或 `0`，与窗口挖洞区域错位，缝隙会露出桌面壁纸。

全屏朝向若按瞬时窗口宽高判断，可能与系统旋转指令竞争，导致窗口方向反复切换。

### 状态管理

- 不要在可复用的列表子组件（如 `FilmRow`、`FilmCard`）内声明窗口尺寸或规避区相关的 `@StorageLink`。
- 由页面或父容器（如 `RecommendTab`）统一订阅 `WIDTH_BP`、`SAFE_INSET_LEFT`、`SAFE_INSET_RIGHT` 等键，再通过 `@Prop` 向下传递。`RecommendTab` 最多展示 `12` 组 `FilmRow`，卡片宽度由 `Breakpoint.cardWidth` 计算后传入。
- 在 `WindowBar.flush` 中对 `SAFE_INSET_TOP`、`SAFE_INSET_BOTTOM`、`SAFE_INSET_LEFT`、`SAFE_INSET_RIGHT` 和 `KEYBOARD_HEIGHT` 做历史值比对，仅在像素值变化时调用 `AppStorage.setOrCreate`。
- `avoidAreaChange` 回调用事件数据更新内存缓存，不要在每次回调中再次调用 `getWindowAvoidArea`。规避区结算在 `WindowBar.scheduleFlush` 中合并，间隔为 `16ms`；窗口尺寸变化则立即调用 `flush`。

### XComponent

- 不要仅依据 `onAreaChange` 的异步结果，为 `XComponent` 动态指定百分比宽高。
- 使用声明式布局：根据缩放模式锁定一个方向为 `100%`，另一方向保持 `undefined`，并由 `.aspectRatio` 按视频实际宽高计算。宽高尚未就绪时，横屏视频使用 `16:9`，竖屏视频使用 `9:16`。
  - 适应（`FIT`）：容器比视频更宽时锁定高度为 `100%`，更窄时锁定宽度为 `100%`。
  - 填充（`COVER`）与适应相反。
  - 拉伸（`STRETCH`）宽高均为 `100%`，不设置 `aspectRatio`。
- 为 `XComponent` 设置 `.constraintSize`：适应模式使用 `maxWidth` / `maxHeight` 为 `100%`，填充模式使用 `minWidth` / `minHeight` 为 `100%`。
- 播放器外层容器须设置 `.clip(true)`，避免 Surface 溢出。
- `onAreaChange` 仅用于记录容器尺寸，供缩放模式判断容器与视频的宽高比，不得据此直接改写 `XComponent` 的宽高百分比。

### 全屏朝向

- 进入全屏时立即锁定目标朝向：横屏视频使用 `window.Orientation.LANDSCAPE`，竖屏视频使用 `window.Orientation.PORTRAIT`。实现见 `AppOrientation.setFullscreenRotation`。
- 退出全屏后恢复 `window.Orientation.AUTO_ROTATION_RESTRICTED`。

### 布局禁用项

- 不要在页面根容器上使用 `.renderGroup(true)` 或根级 `.clip(true)`，以免转场期间复用未更新的离屏纹理。
- 不要在列表卡片根节点上挂载全局 `.animation()`。按压缩放等局部交互动效须在 `onTouch` 中使用 `this.getUIContext().animateTo` 显式驱动。
- 不要在滚动列表项中使用实时毛玻璃 `.backdropBlur`，改用半透明纯色背景。
- 在 `WindowBar.applyBarColors()` 中将窗口背景设为 `AppTheme.BG`，使窗口层与页面底色一致。

## 相关文档

[总览](../README.md)
