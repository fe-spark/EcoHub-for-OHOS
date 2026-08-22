# EcoHub App for OHOS

[EcoHub](https://github.com/fe-spark/EcoHub) 的 OpenHarmony / HarmonyOS 原生客户端。装到手机或平板后，连接你自己部署的 EcoHub 服务。

本仓库 **不是 EcoHub 本体**。EcoHub 是自托管影视聚合的服务端和 Web；这里只做 OHOS App，产物是 HAP 安装包。

| | EcoHub | EcoHub App for OHOS |
| --- | --- | --- |
| 是什么 | 服务端 + Web | OHOS App |
| 仓库 | [fe-spark/EcoHub](https://github.com/fe-spark/EcoHub) | [fe-spark/ecohubapp-for-ohos](https://github.com/fe-spark/ecohubapp-for-ohos) |
| 产物 | Docker 镜像 / 网站 | `.hap` 安装包 |
| 设备显示名 | — | EcoHub |
| 包名 | — | `com.ecohub.spark` |

在 EcoHub 主仓里作为 git submodule，路径为 `ecohubapp-for-ohos/`。

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
