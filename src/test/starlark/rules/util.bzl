"""Shared utilities for the Kotlin Starlark rule tests."""

def basename_of(path):
    """Extract basename from a path string."""
    return path.split("/")[-1]

def values_for_flag_of(action_subject, flag):
    return action_subject.argv().transform(desc = "parsed()", loop = _curry_denormalise_flags_with(flag))

def _curry_denormalise_flags_with(flag):
    def _denormalise_flags(argv):
        parsed_flags = []

        # argv might be none for e.g. builtin actions
        if argv == None:
            return parsed_flags
        last_flag = None
        for arg in argv:
            value = None
            if arg == "--":
                # skip the rest of the arguments, this is standard end of the flags.
                break
            if arg.startswith("-"):
                if "=" in arg:
                    last_flag, value = arg.split("=", 1)
                else:
                    last_flag = arg
            elif last_flag:
                # have a flag, therefore this is probably an associated argument
                value = arg
            else:
                # skip non-flag arguments
                continue

            # only set the value if it exists
            if value:
                if last_flag == flag:
                    parsed_flags.append(value)
        return parsed_flags

    return _denormalise_flags

def abi_jar_of(jar):
    if jar.endswith(".abi.jar"):
        return jar
    else:
        return jar.replace(".jar", ".abi.jar")
