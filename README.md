# EcoHub for OHOS

[![Release](https://img.shields.io/github/v/release/fe-spark/EcoHub-for-OHOS)](https://github.com/fe-spark/EcoHub-for-OHOS/releases)
[![Download HAP](https://img.shields.io/badge/Download-.hap-orange?logo=huawei&logoColor=white)](https://github.com/fe-spark/EcoHub-for-OHOS/releases/latest)
[![OpenHarmony](https://img.shields.io/badge/OpenHarmony-API%2013+-blue)](https://www.openharmony.cn/)

[EcoHub](https://github.com/fe-spark/EcoHub) 的 OpenHarmony / HarmonyOS 原生客户端。

> [!NOTE]
> 本仓库是 EcoHub 的客户端，不提供、不存储任何影视资源。安装后需配置并接入 EcoHub 软件源（服务端），方可浏览与观影。

相关项目：[EcoHub 主仓库（服务端 + Web）](https://github.com/fe-spark/EcoHub) · [EcoHub for Android](https://github.com/fe-spark/EcoHub-for-Android)

<div align="center">

<img src="./preview.jpg" alt="EcoHub for OHOS 截图" width="360" />

</div>

---

## 下载安装

- [下载最新版本 HAP](https://github.com/fe-spark/EcoHub-for-OHOS/releases/latest)
- [查看历史版本与更新说明](https://github.com/fe-spark/EcoHub-for-OHOS/releases)

---

## 配置软件源

客户端的影视列表、分类、搜索和播放地址均由 EcoHub 软件源提供。

### 获取地址

- **自建部署（推荐）**  
  按照 [EcoHub 部署指南](https://github.com/fe-spark/EcoHub/blob/main/docs/README-Deploy.md) 部署 EcoHub 服务端。部署完成后，在管理后台「工作台」点击「订阅地址」，获取客户端订阅源：

  ```text
  http://<服务器 IP 或域名>:3000/api/provide/app
  ```

  若已配置 HTTPS 或反向代理，格式为 `https://<域名>/api/provide/app`。在管理后台完成影视数据采集后，客户端即可同步。

- **他人分享**  
  亦可填入他人已部署或公开的 EcoHub 软件源地址。示例：`https://eco.fe-spark.cn/api/provide/app`。

### 在 App 中配置

1. 打开应用。首次启动或尚未配置软件源时，将进入软件源配置页。软件源连接失败时，亦会进入该页。
2. 在「软件源地址」中填入站点根地址（如 `http://<服务器 IP 或域名>:3000`），或后台提供的完整订阅地址。
3. 点击「开始观影」（重新连接时为「重新接入」）。应用将请求 `/api/provide/app` 检测连通性。
4. 校验通过后进入首页。之后可在「我的」中点击「软件源」，管理或切换历史软件源。

未填写协议时，将自动补全为 `https://`。

若站点开启了私有化访问，在地址末尾追加 `?key=<密钥>`。

填写 `/api/provide/app`、`/provide/app` 或 `/api` 路径时，将解析为站点根地址。

---

## 推荐

### 服务器

| 服务商 | 说明 | 链接 |
| --- | --- | --- |
| CloudCone | 1. 演示站点所用服务商<br>2. 高性价比 VPS，磁盘 I/O 不受限 | [前往选购](https://app.cloudcone.com/?ref=14393) |

### 网络服务

| 服务商 | 特点 / 价格 | 链接 |
| --- | --- | --- |
| 良心云 | 低至 2 元/月<br>新用户注册即获体验流量 | [前往注册](https://xn--9kqz23b19z.com/#/register?code=xAmvfdic) |
| 赔钱机场 | 低至 1.5 元/月<br>适合高流量与备用需求 | [前往注册](https://xn--mes358aby2apfg.com/register?code=FA4xlzHD&cover=sfw) |
| DOVE | 适合长期稳定 | [前往注册](https://dovee.cc/a.php?asbcbO1PCgTx2JM66) |

---

## 本地开发

使用 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 打开本工程目录，进行调试与打包构建。

---

## 开源许可

本项目遵循 [PolyForm Noncommercial 1.0.0](./LICENSE) 协议。
