### 更新说明 (v1.1.2-beta.1)

- **访问埋点**：首页浏览、搜索、播放、分类页上报 `POST /api/stat/view`，User-Agent 带 `EcoHub-OHOS/{version}`。
- **ArkTS 适配**：埋点 POST body 改为显式 `TrackViewPayload`，避免无类型对象字面量编译失败。
- **版本检查**：正式版用户不提示 GitHub pre-release。
