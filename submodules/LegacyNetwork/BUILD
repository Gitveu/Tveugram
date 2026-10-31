load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "LegacyNetwork",
    module_name = "Network",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
        "-enable-library-evolution",
    ],
    visibility = [
        "//visibility:public",
    ],
    alwayslink = True,
)
