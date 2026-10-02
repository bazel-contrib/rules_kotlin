"""The PluginPhase values that payload.bzl maps the rules' phase names to, as a file for PluginsPayloadPhaseNamesTest."""

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//src/main/starlark/core/plugin:payload.bzl", "plugin_payload")

def plugin_phase_names(name):
    """Writes the values of the phase table of payload.bzl, one per line, in the order of its keys.

    Args:
        name: the name of the target; the file is `<name>.txt`.
    """
    phases = plugin_payload.plugin_phases
    write_file(
        name = name,
        out = name + ".txt",
        content = [phases[phase] for phase in sorted(phases)],
    )
