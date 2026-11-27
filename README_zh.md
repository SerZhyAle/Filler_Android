# Android 版 Filler

<!-- languages -->
语言： [English](README.md) - [Русский](README_ru.md) - [Українська](README_uk.md) - [Deutsch](README_de.md) - [Italiano](README_it.md) - [Español](README_es.md) - [Français](README_fr.md) - [Português](README_pt.md) - [العربية](README_ar.md) - [हिन्दी](README_hi.md) - [বাংলা](README_bn.md) - [اردو](README_ur.md) - 简体中文
<!-- /languages -->

Filler 用临时文件填满存储设备的可用空间，然后将其删除。您选择内部存储、存储卡或其中的文件夹；Filler 显示它测得的可用空间以及为系统保留的空闲部分，写入不超过您确认的数量，期间始终显示已写入的数量、百分比和剩余时间，并删除它写入的每一个文件 - 无论是在运行完成、停止、写入错误、重启还是存储卡被移除之后。您自己的文件保持不变。在手机上，填充还可以按计划运行：在设定的时间、应用关闭时进行，即使重启过也一样，保留通常的 1 GB 可用空间，每天最多一次，每次运行都列在历史记录中。一个应用标识符 `com.sza.filler` 同时涵盖 Android 应用和 Wear OS 应用。

它是将 FastMediaSorter 的本地存储 Filler 功能独立出来的应用，也是一个独立产品：它与该系列的其他产品不共享任何应用代码，只共享已发布的约定规范。

## 构建

安装 JDK 和 Android SDK 后，运行 `./gradlew :phone:assembleDebug :wear:assembleDebug` 即可构建手机应用和手表应用的调试版 APK。产品的由来见 [docs/PLAN_BOOTSTRAP_HANDOFF.md](docs/PLAN_BOOTSTRAP_HANDOFF.md)。

## 隐私

开发者收不到您的任何数据：没有账号，没有使用分析，没有广告，没有跟踪。Filler 没有网络访问权限，因此任何内容都不会离开设备；手机应用只请求让计划填充在应用关闭时按时运行所需的权限，手表应用只请求让填充在屏幕熄灭时继续进行所需的权限。完整政策：[隐私政策](https://serzhyale.github.io/Filler_Android/privacy-zh.html)。

## 安装来自 GitHub Releases 或 SourceForge 的 APK

在 Google Play 之外发布的已签名手机版和手表版 APK，会使 Android 要求允许来自某一来源的未知应用，并可能显示 Play Protect 关于开发者的提示。每个提示是什么、为什么出现以及具体应该点按什么，见[安装指南](docs/INSTALL_TRUST-zh.md)。Google Play 上的同一应用由 Play App Signing 签名，不会遇到任何这些提示。

## 联系方式

电子邮件 [sza@ukr.net](mailto:sza@ukr.net)，GitHub [SerZhyAle](https://github.com/SerZhyAle)。欢迎通过 [GitHub issues](https://github.com/SerZhyAle/Filler_Android/issues) 提问和报告错误。

本项目的开发大量借助 AI；作者审查每一处改动。

## 许可证

MIT - 见 [LICENSE](LICENSE)。

<!-- Rendered by tools/locale/render-translations.ps1 from README.md and tools/locale/dictionaries/zh.json. Never edit it by hand. -->
