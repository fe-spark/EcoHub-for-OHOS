# EcoHub for OHOS

[EcoHub](https://github.com/fe-spark/EcoHub) 的 OpenHarmony / HarmonyOS 原生客户端。装到手机或平板后，连接你自己部署的 EcoHub 服务。

本仓库 **不是 EcoHub 本体**。EcoHub 是自托管影视聚合的服务端和 Web；这里只做 OHOS App，产物是 HAP 安装包。

同级还有 [EcoHub for Android](https://github.com/fe-spark/app-for-android)。

| | EcoHub | EcoHub for OHOS |
| --- | --- | --- |
| 是什么 | 服务端 + Web | OHOS App |
| 仓库 | [fe-spark/EcoHub](https://github.com/fe-spark/EcoHub) | [fe-spark/app-for-ohos](https://github.com/fe-spark/app-for-ohos) |
| 产物 | Docker 镜像 / 网站 | `.hap` 安装包 |
| 设备显示名 | — | EcoHub |
| 包名 | — | `com.ecohub.spark` |

在 EcoHub 主仓里作为 git submodule，路径为 `app-for-ohos/`。

## 开发

使用 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 打开本目录。
