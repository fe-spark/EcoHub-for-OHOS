# UI 与设计规范

## 1. 基础技术栈
- **UI 框架**：HarmonyOS 原生声明式 ArkTS 组件（`@kit.ArkUI`）。
- **组件库**：系统原生组件（`Button`、`List`、`Grid`、`Swiper`、`TextInput`、`Slider`、`LoadingProgress`、`SymbolGlyph` 等），不引入冗余第三方 UI 库。

## 2. 设计规范与色彩 Token
项目采用全局深色设计系统，统一通过 `common/constants/AppTheme.ets` 引用设计 Token，禁止硬编码颜色与边距：
- **背景色**：
  - 主背景：`AppTheme.BG` (`#0A0B10`)
  - 浮层/卡片：`AppTheme.BG_ELEVATED` (`#12141C`)、`AppTheme.BG_CARD` (`#1A1C24`)、`AppTheme.BG_CHIP` (`#22242E`)
- **主色调**：
  - 强调色（Accent）：`AppTheme.ACCENT` (`#FA8C16`) / `AppTheme.ACCENT_SOFT` (`rgba(250, 140, 22, 0.18)`)
  - 危险色（Danger）：`AppTheme.DANGER` (`#FF4D4F`) / `AppTheme.DANGER_SOFT` (`rgba(255, 77, 79, 0.18)`)
- **字体与边框**：
  - 一级文字：`AppTheme.TEXT_PRIMARY` (`#FFFFFF`)
  - 二级文字：`AppTheme.TEXT_SECONDARY` (`rgba(255, 255, 255, 0.65)`)
  - 弱化文字：`AppTheme.TEXT_MUTED` (`rgba(255, 255, 255, 0.40)`)
  - 分割边框：`AppTheme.BORDER` (`rgba(255, 255, 255, 0.08)`)

## 3. 布局与组件规范
- 页面顶部必须通过 `WindowBar.apply` 适配沉浸式状态栏与屏幕安全区（避让区）。
- 弹窗采用居中 Spring 弹性动效，背景遮罩透明度为 `0.72`。
- 图标统一使用系统 `SymbolGlyph` 或封装的 `AppIcon` / `BackIcon` 组件。
