// swift-tools-version: 6.0
import Foundation
import PackageDescription
let local = "BinaryTarget/CLibSolv.xcframework"
let exists = FileManager.default.fileExists(atPath: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent(local).path)
let binary: Target = exists
    ? .binaryTarget(name: "CLibSolv", path: local)
    : .binaryTarget(name: "CLibSolv", url: "https://github.com/Lakr233/libsolv.xcframework/releases/download/upstream.0e6eea45c9ff.1/CLibSolv.xcframework.zip", checksum: "a16211549a5e2026b40a33bfe9f4b3eda553778837f9e4f59e86741adcb2c24e")
let package = Package(
    name: "LibSolv",
    platforms: [.macOS(.v10_13), .macCatalyst("13.1"), .iOS(.v12), .tvOS(.v12), .watchOS(.v5), .visionOS(.v1)],
    products: [
        .library(name: "LibSolv", targets: ["LibSolv"]),
        .library(name: "LibSolvDynamic", type: .dynamic, targets: ["LibSolv"]),
    ],
    targets: [binary, .target(name: "LibSolv", dependencies: ["CLibSolv"]),
              .testTarget(name: "LibSolvTests", dependencies: ["LibSolv"])],
    swiftLanguageModes: [.v6]
)
