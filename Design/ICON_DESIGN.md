# Proxy Studio 应用图标

设计主题：连接与转换。两枚圆角方环交扣，方形轮廓呼应二维码定位框；白色与薄荷色主体搭配青绿色背景，与应用中的 teal 强调色一致。

生成方式：内置 image_gen 工具生成默认版，并以默认版为参考编辑 Dark、Tinted 两个变体。使用系统 sips 缩放为 Xcode 需要的 1024×1024，Tinted 额外通过 ColorSync 转换至 Gray Gamma 2.2。没有文字或预先裁切的外圆角。

交付资源：
- AppIcon-Master.png：生成原稿。
- AppIcon-Dark-Master.png：深色版生成原稿，青蓝与翡翠绿主体，保留透明背景。
- AppIcon-Tinted-Master.png：着色版生成原稿；正式资源已消除原稿轻微色偏。
- ../ProxyStudio/Platforms/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png：正式应用图标。
- ../ProxyStudio/Platforms/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png：Dark 槽位，RGBA，背景透明。
- ../ProxyStudio/Platforms/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-Tinted.png：Tinted 槽位，Gray Gamma 2.2，不透明。
- 工程 Debug、Release 均指向 AppIcon。

此版本为三种外观的静态 PNG 资源，未制作 Icon Composer 分层文件。深色透明背景与着色灰度图遵循 [Apple 资源目录说明](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)。变体保留相扣方环的构图与视觉身份，由生成式编辑制作，几何并非逐像素完全一致。

## 最终生成提示词

Dark 和 Tinted 的完整编辑提示词见 [VARIANT_PROMPTS.md](VARIANT_PROMPTS.md)。

Use case: logo-brand. Create one production-ready iOS app icon for Proxy Studio, a local SOCKS-link to QR-code and Clash-config utility. Deliver a single exact 1024 x 1024 square image, full bleed, fully opaque, no outside frame, no premasked rounded corners. Background fills every pixel: refined deep ocean teal to vivid jade gradient, calm and clean. Center one bold original emblem occupying about 66 percent of the canvas: two interlocking rounded-square chain links arranged on a subtle lower-left to upper-right diagonal, with the squared geometry recalling QR finder patterns. The interlocking links must read immediately as one coherent connected symbol at 40 pixels. Use luminous porcelain-white and very pale mint glass with restrained soft dimensionality, gently beveled edges and a subtle close contact shadow; crisp silhouette, generous breathing room, polished contemporary Apple-platform utility aesthetic. The subject is graphic and geometric, not a photographed object. Strong light-dark contrast, precise balanced optical centering. No text, no letters, no digits, no actual QR code, no tiny dots, no shield, no padlock, no arrows, no extra decoration, no phone mockup, no watermark, no border. Do not show multiple proposals or a presentation sheet. Just the final square app icon artwork.
