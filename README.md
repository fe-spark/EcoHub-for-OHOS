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
| iKuuu | 老牌稳定机场 <br>新用户注册即获体验流量 | [前往注册](https://ikuuu.top/auth/register?code=Uubm) |

---

## 🛠️ 本地开发

使用 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 打开本工程目录进行调试与打包构建。

---

## 📄 开源许可

本项目遵循 [PolyForm Noncommercial 1.0.0](https://github.com/fe-spark/EcoHub/blob/main/LICENSE) 协议。
