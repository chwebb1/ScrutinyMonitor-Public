import XCTest
import SwiftUI
import AppKit

@MainActor
func assertSnapshot<V: View>(
    matching view: V,
    named name: String,
    width: CGFloat = 400,
    height: CGFloat = 300,
    colorScheme: ColorScheme = .dark,
    record: Bool = false,
    file: StaticString = #file,
    line: UInt = #line
) {
    // 1. Initialize the shared NSApplication so we have an active Window Server connection
    _ = NSApplication.shared
    
    // 2. Frame the view and apply consistent Dark Mode/Light Mode styling to prevent visual discrepancies
    let framedView = view
        .frame(width: width, height: height)
        .environment(\.colorScheme, colorScheme)
    
    let hostingView = NSHostingView(rootView: framedView)
    hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
    
    // 3. Create an offscreen window to establish a graphics hierarchy
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: width, height: height),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = hostingView
    
    // Force layout passes
    hostingView.layoutSubtreeIfNeeded()
    window.display()
    
    // 4. Render the view hierarchy directly into a consistent @1x (non-Retina) sRGB bitmap representation
    let widthInt = Int(width)
    let heightInt = Int(height)
    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: widthInt,
        pixelsHigh: heightInt,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: widthInt * 4,
        bitsPerPixel: 32
    ) else {
        XCTFail("Failed to create consistent @1x NSBitmapImageRep", file: file, line: line)
        return
    }
    bitmapRep.size = NSSize(width: width, height: height)
    
    let previousContext = NSGraphicsContext.current
    let nsContext = NSGraphicsContext(bitmapImageRep: bitmapRep)
    NSGraphicsContext.current = nsContext
    
    hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)
    
    NSGraphicsContext.current = previousContext
    
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        XCTFail("Failed to serialize bitmap to PNG data", file: file, line: line)
        return
    }
    
    // 5. Locate or create __Snapshots__ folder relative to the test file
    let fileURL = URL(fileURLWithPath: String(describing: file))
    let testDirectoryURL = fileURL.deletingLastPathComponent()
    let snapshotDirectory = testDirectoryURL.appendingPathComponent("__Snapshots__")
    let snapshotURL = snapshotDirectory.appendingPathComponent("\(name).png")
    
    if record {
        // Record new reference snapshot
        do {
            try FileManager.default.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
            try pngData.write(to: snapshotURL)
            XCTFail("Snapshot successfully recorded: \(snapshotURL.lastPathComponent). Turn off record mode and re-run.", file: file, line: line)
        } catch {
            XCTFail("Failed to write snapshot reference: \(error)", file: file, line: line)
        }
        return
    }
    
    // 6. Automatic baseline generation
    guard FileManager.default.fileExists(atPath: snapshotURL.path) else {
        do {
            try FileManager.default.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
            try pngData.write(to: snapshotURL)
            XCTFail("Automatic snapshot baseline recorded: \(snapshotURL.lastPathComponent). Re-run to verify.", file: file, line: line)
        } catch {
            XCTFail("Failed to write automatic snapshot reference: \(error)", file: file, line: line)
        }
        return
    }
    
    // 7. Load reference snapshot
    guard let referenceImage = NSImage(contentsOf: snapshotURL) else {
        XCTFail("Failed to load reference snapshot at: \(snapshotURL.path)", file: file, line: line)
        return
    }
    
    // 8. Visual equivalence comparison using normalized 32-bit pixel buffers
    let currentImage = NSImage(data: pngData)!
    
    let isCI = ProcessInfo.processInfo.environment["CI"] == "true"
    let tolerancePercent = isCI ? 15.0 : 2.0
    let channelTolerance = isCI ? 25 : 8
    
    if !imagesAreVisuallyEqual(
        image1: currentImage,
        image2: referenceImage,
        tolerancePercent: tolerancePercent,
        channelTolerance: channelTolerance
    ) {
        let failedDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScrutinyMonitorSnapshotFailures", isDirectory: true)
        let failedURL = failedDirectory.appendingPathComponent("\(name)_failed.png")
        var writeErrorDetails: String = ""
        do {
            try FileManager.default.createDirectory(at: failedDirectory, withIntermediateDirectories: true)
            try pngData.write(to: failedURL)
        } catch {
            writeErrorDetails = " (Note: Failed to save snapshot artifact: \(error.localizedDescription))"
        }
        XCTFail("Snapshot mismatch for '\(name)'. New failure output saved to: \(failedURL.path)\(writeErrorDetails)", file: file, line: line)
    }
}

private func imagesAreVisuallyEqual(
    image1: NSImage,
    image2: NSImage,
    tolerancePercent: Double,
    channelTolerance: Int
) -> Bool {
    guard let cgImage1 = image1.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let cgImage2 = image2.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return false
    }
    
    guard cgImage1.width == cgImage2.width,
          cgImage1.height == cgImage2.height else {
        return false
    }
    
    let width = cgImage1.width
    let height = cgImage1.height
    
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    let totalBytes = height * bytesPerRow
    
    var rawData1 = [UInt8](repeating: 0, count: totalBytes)
    var rawData2 = [UInt8](repeating: 0, count: totalBytes)
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context1 = CGContext(
        data: &rawData1,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
    
    let context2 = CGContext(
        data: &rawData2,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
    
    guard let ctx1 = context1, let ctx2 = context2 else { return false }
    
    ctx1.draw(cgImage1, in: CGRect(x: 0, y: 0, width: width, height: height))
    ctx2.draw(cgImage2, in: CGRect(x: 0, y: 0, width: width, height: height))
    
    // Fast path: if memory matches exactly, avoid expensive pixel loop
    if rawData1 == rawData2 {
        return true
    }

    var differingPixels = 0
    let pixelCount = width * height
    
    for i in stride(from: 0, to: totalBytes, by: bytesPerPixel) {
        let r1 = rawData1[i]
        let g1 = rawData1[i+1]
        let b1 = rawData1[i+2]
        let a1 = rawData1[i+3]
        
        let r2 = rawData2[i]
        let g2 = rawData2[i+1]
        let b2 = rawData2[i+2]
        let a2 = rawData2[i+3]
        
        let diffR = abs(Int(r1) - Int(r2))
        let diffG = abs(Int(g1) - Int(g2))
        let diffB = abs(Int(b1) - Int(b2))
        let diffA = abs(Int(a1) - Int(a2))
        
        if diffR > channelTolerance || diffG > channelTolerance || diffB > channelTolerance || diffA > channelTolerance {
            differingPixels += 1
        }
    }
    
    let allowedDifferences = Int(Double(pixelCount) * (tolerancePercent / 100.0))
    
    // Print diagnostic details if comparison fails to help with troubleshooting
    if differingPixels > allowedDifferences {
        let mismatchPercent = (Double(differingPixels) / Double(pixelCount)) * 100.0
        print("Visual mismatch details - Differing pixels: \(differingPixels)/\(pixelCount) (\(String(format: "%.2f", mismatchPercent))%). Allowed: \(allowedDifferences) (\(tolerancePercent)%). Channel tolerance: \(channelTolerance)")
    }
    
    return differingPixels <= allowedDifferences
}
