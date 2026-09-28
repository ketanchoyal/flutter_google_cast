// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// This Package.swift enables Swift Package Manager (SPM) support for the flutter_chrome_cast plugin.
// The plugin maintains dual support for both CocoaPods (via flutter_chrome_cast.podspec) and SPM.
//
// The Google Cast SDK dependency is provided by the SRGSSR community wrapper since Google does not
// officially provide an SPM-compatible distribution.

import PackageDescription

let package = Package(
    name: "flutter_chrome_cast",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(
            name: "flutter-chrome-cast",
            targets: ["flutter_chrome_cast"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "flutter_chrome_cast",
            dependencies: [
                .target(name: "GoogleCast")
            ],
            exclude: [
                // Exclude Objective-C files - they are used by CocoaPods only
                // Flutter's build system generates plugin registration code separately
                "GoogleCastPlugin.m",
                "GoogleCastPlugin.h"
            ],
            resources: [
                // TODO: If your plugin requires a privacy manifest
                // (e.g. if it uses any required reason APIs), update the PrivacyInfo.xcprivacy file
                // to describe your plugin's privacy impact, and then uncomment this line.
                // .process("PrivacyInfo.xcprivacy"),
            ]
        ),
        .binaryTarget(
            name: "GoogleCast",
            url: "https://github.com/SRGSSR/google-cast-sdk/releases/download/4.8.6/GoogleCast.xcframework.zip",
            checksum: "55f6c21291a1315c68063f07e7d76225564bff70f2fd38caad135c71d66eb310"
        )
    ]
)
