// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "anyedit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "anyedit",
            targets: ["anyedit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pvieito/PythonKit.git", from: "0.3.1")
    ],
    targets: [
        .executableTarget(
            name: "anyedit",
            dependencies: ["PythonKit"],
            path: "CoolVideoEditorApp",
            resources: [
                .process("Resources"),
                .process("AIModels"),
                .copy("Scripts")
            ]
        )
    ]
) 