# Play listing - Chinese (Simplified) (zh-CN)

The Chinese (Simplified) text of the three store fields of `com.sza.filler`, rendered by
`tools/locale/render-translations.ps1` from [PLAY_LISTING.md](PLAY_LISTING.md) and
`tools/locale/dictionaries/zh.json`; never edit it by hand. The headings are the console's field names.

## Title

Filler: Fill Storage Space

## Short description

用临时文件填满存储设备的空闲空间，然后将其删除

## Full description

Filler 用临时文件填满存储设备的可用空间，然后将其删除。您自己的文件保持不变。

选择位置
在 Android 文件夹选择器中选取内部存储、存储卡或其中的文件夹，也可以直接在 Filler 自己的文件夹中开始。Filler 显示它测得的可用空间以及为系统保留的空闲部分。默认保留 1 GB；运行前您可以将其调低，最少可到 10 MB。

填充并跟踪进度
写入任何内容之前，会有一次确认，列出文件夹、写入量和保留的空闲部分。运行期间，您可以看到已写入的数量、百分比和剩余时间。随时可以停止，此前写入的文件会被删除。

始终清理
Filler 只删除自己写入的文件，绝不删除其他任何内容。它保存这些文件的清单，因此在停止、写入错误、重启或存储卡被移除之后，只要存储设备重新可用，它就会提示删除剩下的文件。

按计划运行
保存一个计划，Filler 就会在设定的时间、应用关闭时填充某个文件夹，即使手机重启过也一样，然后删除这些文件。计划填充始终保留通常的 1 GB 可用空间，每天最多运行一次，每次运行都会连同时间和结果列出。

任何设备，还有手表
Filler 支持触摸、键盘、鼠标和 D-pad，支持纵向和横向屏幕，可在手机、平板电脑和其他 Android 设备以及 Wear OS 手表上使用。

隐私
Filler 没有网络访问权限：没有账号，没有使用分析，没有广告，没有跟踪。任何内容都不会离开您的设备。

Android 应用的界面提供 13 种语言。

## What's new

适用于 Android 手机、平板电脑和 Wear OS 手表的 Filler 首个版本：用临时文件填充可用空间并在之后删除，设置保留的可用空间，安排自动运行，切换颜色主题，使用内置帮助浮层，并在无网络访问的情况下使用 13 种语言运行应用。
