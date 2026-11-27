# 为什么 Android 会对 Filler APK 发出警告 - 以及应该点按什么

<!-- languages -->
语言： [English](INSTALL_TRUST.md) - [Русский](INSTALL_TRUST-ru.md) - [Українська](INSTALL_TRUST-uk.md) - [Deutsch](INSTALL_TRUST-de.md) - [Italiano](INSTALL_TRUST-it.md) - [Español](INSTALL_TRUST-es.md) - [Français](INSTALL_TRUST-fr.md) - [Português](INSTALL_TRUST-pt.md) - [العربية](INSTALL_TRUST-ar.md) - [हिन्दी](INSTALL_TRUST-hi.md) - [বাংলা](INSTALL_TRUST-bn.md) - [اردو](INSTALL_TRUST-ur.md) - 简体中文
<!-- /languages -->

Filler 是一位独立开发者制作的免费小应用。当您从 GitHub Releases 或 SourceForge 而不是 Google Play 安装已签名的 APK 时，Android 会在安装过程中显示几个提示。下面说明这些提示是什么、为什么出现，以及具体应该点按什么。

## 1. 警告是什么

您可能会遇到两种提示。引号中的文字是 Android 显示给您的内容（英文原文；括号中的译文仅供理解）：

- **"For security, your phone currently isn't allowed to install unknown apps from this source."**（出于安全考虑，您的手机目前不允许安装来自此来源的未知应用）。当您第一次从尚未获准安装应用的浏览器或文件管理器中打开 APK 时，Android 会显示它。其中有一个 **Settings**（设置）按钮。按钮后面的界面名为 **Install unknown apps**（安装未知应用），该权限按应用分别授予：您的浏览器或您的文件管理器。
- **"Play Protect doesn't recognize this app's developer"**（Play Protect 无法识别此应用的开发者）（或 **"App blocked to protect your device"**，为保护您的设备，应用已被拦截）。Play Protect 是内置于 Google Play 服务的扫描器。它可能提供 **More details**（更多详情）和 **Install anyway**（仍然安装），或者 **OK**。

不同 Android 版本和厂商的措辞略有差异。引号中是英文原文；在设置为其他语言的手机上，Android 会显示它自己的译文（本页不引用该译文，因为无法针对每个版本进行确认）。

## 2. 为什么会出现

- **未知应用。** Android 把所有并非来自已安装应用商店的应用视为来自“未知来源”，并针对打开该文件的应用询问您一次。这个提示针对的是来源，而不是 Filler。
- **Play Protect。** GitHub Releases 和 SourceForge 上的 APK 使用 Filler 自己的发布密钥签名，且不属于 Google Play 统计过的安装，因此 Play Protect 没有该开发者的历史记录。新的独立开发者在安装量积累起来之前不会被识别；该警告并不表示应用有害，也不是错误或程序缺陷。随着安装的人增多，它可能会消失；但这并不是承诺。
- **Google Play。** Google Play 上的同一应用由 Play App Signing 签名，不会遇到这些提示。如果想跳过它们，请从 Google Play 安装。

安装前，您可以将文件与旁边发布的 `.sha256` 文件进行比对：两者必须是相同的 SHA-256 值。值不同表示下载的文件已损坏或并非 Filler 的文件；请将其删除。

## 3. 应该点按什么

1. 从浏览器或文件管理器中打开下载的 APK。
2. 出现 **"For security, your phone currently isn't allowed to install unknown apps from this source."** 时，点按 **Settings**，仅为该应用（您的浏览器或文件管理器）开启 **Allow from this source**（允许来自此来源的应用），然后返回。
3. 点按 **Install**（安装）。出现 **"Play Protect doesn't recognize this app's developer"** 时，点按 **More details**，再点按 **Install anyway**。Filler 不再要求任何其他内容。
4. 之后请再次关闭 **Allow from this source**：在 Android 设置中依次打开 **Apps**（应用）、您使用过的应用（浏览器或文件管理器）、**Install unknown apps**。此项按应用分别设置，随时可以撤销。

不要为了安装 Filler 而关闭 Play Protect，也不要停用任何其他保护功能：这里完全不需要。手表应用以同样的方式安装到手表上，使用您用来安装手表 APK 的任意工具即可；出现的提示相同。

## 4. Filler 绝不会做的事

此清单与[隐私政策](https://serzhyale.github.io/Filler_Android/privacy-zh.html)以及 Google Play 的 Data safety 回答内容一致。

- 它没有网络权限，因此不向任何人发送任何内容：不发给开发者，不发给服务器，也不发给其他应用。
- 它没有使用分析、崩溃报告、广告或跟踪代码，也不创建任何账号。
- 它不打开、读取、复制或更改您自己的文件，并且只删除自己写入的临时文件。
- 它不读取您的联系人、照片、消息、位置或其他应用的数据。
- 手机应用请求五项权限，手表应用请求四项，仅用于让填充按时运行并在屏幕熄灭时继续进行；其中没有任何一项提供对您的文件或网络的访问。

<!-- Rendered by tools/locale/render-translations.ps1 from INSTALL_TRUST.md and tools/locale/dictionaries/zh.json. Never edit it by hand. -->
