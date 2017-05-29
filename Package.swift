// required: `libz-dev`, `libcairo-dev` `libjpeg-dev`,
// libglfw3: must be compiled → sudo apt-get install cmake xorg-dev → [build glfw3.2]

import PackageDescription

let package = Package(
    name: "Diannamy",
    targets: [
                Target(name: "SwiftCairo", dependencies: ["Cairo"]),
                Target(name: "Diannamy", dependencies: ["GLFW", "SwiftCairo", "Taylor", "Geometry"])
             ],
    dependencies: [.Package(url: "../SGLOpenGL", majorVersion: 1),
                   .Package(url: "../../noise", Version("0.0.0")), 
                   .Package(url: "https://github.com/kelvin13/maxpng", majorVersion: 2)
                   ],
    swiftLanguageVersions: [3, 4],
    exclude: ["Sources/Shaders"]
                )
