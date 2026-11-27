"""JVM flags shared by the rules_kotlin worker binaries."""

MAX_FD_LIMIT_JVM_FLAGS = select({
    "@platforms//os:macos": ["-XX:-MaxFDLimit"],
    "//conditions:default": [],
})
