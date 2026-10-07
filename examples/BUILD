load(":integration.bzl", "derive_metadata", "example_integration_test_suite")

SHARD_COUNT = 3

[
    example_integration_test_suite(
        name = example,
        metadata = metadata,
        tags = ["shard_%s" % (idx % SHARD_COUNT)],
    )
    for (
        idx,
        (example, metadata),
    ) in enumerate({
        example: derive_metadata(
            directory = example,
        )
        for example in {
            # Cut to the directory, de-duplicate via dict.
            file.partition("/")[0]: True
            for file in glob(
                ["**/*"],
                # Exclude files in `examples`.
                exclude = [
                    "*",
                    # Node is currently broken.
                    "node/**",
                ],
            )
        }
    }.items())
]
