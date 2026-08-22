# EcoHarmony

EcoHub 的鸿蒙原生客户端。

本仓库作为 [EcoHub](https://github.com/fe-spark/EcoHub) 的 git submodule，路径为 `harmony/`。

## 开发

使用 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 打开本目录。

## CI 打包 HAP

推送到 `main`、打 `v*.*.*` tag，或手动跑 **Build HAP** workflow，会用 HarmonyOS Command Line Tools `6.1.1.280`（对应 API 6.1.1(24)）执行 `hvigorw assembleHap`，产物上传为 Actions artifact。

tag 推送时会把 HAP 挂到对应 GitHub Release。

本机 `build-profile.json5` 里的签名路径不会在 CI 使用。要打可安装的签名包，在仓库 Settings → Secrets 配置：

| Secret | 说明 |
| --- | --- |
| `HOS_SIGN_P12` | `.p12` 的 base64 |
| `HOS_SIGN_CERT` | `.cer` 的 base64 |
| `HOS_SIGN_PROFILE` | `.p7b` 的 base64 |
| `HOS_SIGN_KEY_ALIAS` | 可选，默认 `debugKey` |
| `HOS_SIGN_KEY_PASSWORD` | 密钥密码（可用 DevEco 写入 build-profile 的加密串） |
| `HOS_SIGN_STORE_PASSWORD` | 密钥库密码 |

未配置时产出 unsigned HAP。本机编码示例：

```bash
base64 -i ~/.ohos/config/xxx.p12 | pbcopy
```
