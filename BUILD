cc_binary(
    name = "toxic",
    srcs = glob([
        "src/*.c",
        "src/*.h",
    ]),
    copts = [
        "-DAUDIO",
        "-DPACKAGE_DATADIR='\"data\"'",
        "-DPYTHON",
        "-DVIDEO",
        "-I/usr/include/python3.5",
    ],
    linkopts = [
        "-lconfig",
        "-lncurses",
        "-lopenal",
        "-lpython3.5m",
        "-lX11",
    ],
    deps = [
        "//c-toxcore",
        "@curl",
        "@libqrencode",
        "@libvpx",
    ],
)
