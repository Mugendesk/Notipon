#!/usr/bin/env swift

import Cocoa
import AppKit

func generateIcon(size: CGFloat, outputPath: String) {
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()

    // 背景 - Discord風の鮮やかな青
    let cornerRadius = size * 0.225
    let backgroundPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor(red: 0.35, green: 0.51, blue: 0.91, alpha: 1.0).setFill()
    backgroundPath.fill()

    // SF Symbolsのベルアイコン
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: size * 0.6, weight: .semibold)
    if let originalBell = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfig) {

        // 中央配置
        let symbolSize = originalBell.size
        let x = (size - symbolSize.width) / 2
        let y = (size - symbolSize.height) / 2 + size * 0.02
        let drawRect = NSRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height)

        // シャドウ
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(white: 0, alpha: 0.25)
        shadow.shadowOffset = NSSize(width: size * 0.015, height: -size * 0.015)
        shadow.shadowBlurRadius = size * 0.03
        shadow.set()

        // 白色のベルを作成
        let whiteBell = NSImage(size: symbolSize)
        whiteBell.lockFocus()
        NSColor.white.set()
        NSRect(origin: .zero, size: symbolSize).fill()
        originalBell.draw(at: .zero, from: NSRect(origin: .zero, size: symbolSize), operation: .destinationIn, fraction: 1.0)
        whiteBell.unlockFocus()

        // 白いベルを描画
        whiteBell.draw(in: drawRect)
    }

    image.unlockFocus()

    // PNG保存
    if let tiff = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiff),
       let png = bitmap.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: outputPath))
        print("Generated: \(outputPath)")
    }
}

// アイコンセットのパス
let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent().path
let basePath = "\(scriptDir)/NotifyDeck/Resources/Assets.xcassets/AppIcon.appiconset"

// 必要なサイズを生成
let sizes: [(size: CGFloat, name: String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (size, name) in sizes {
    let outputPath = "\(basePath)/\(name)"
    generateIcon(size: size, outputPath: outputPath)
}

print("✅ All icons generated with white SF Symbols!")
