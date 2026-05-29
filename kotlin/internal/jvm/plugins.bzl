# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
load("@rules_java//java:defs.bzl", "JavaInfo", "JavaPluginInfo")
load(
    "//kotlin/internal:defs.bzl",
    _KspPluginInfo = "KspPluginInfo",
)

def is_ksp_processor_generating_java(targets):
    for t in targets:
        if _KspPluginInfo in t:
            if t[_KspPluginInfo].generates_java:
                return True
    return False

# Mapping functions for args.add_all.
# These preserve the transitive depsets until needed.
def _kt_plugin_to_processor(processor):
    return processor.processor_classes.to_list()

def _kt_plugin_to_processorpath(processor):
    return [j.path for j in processor.processor_jars.to_list()]

def _targets_to_annotation_processors(targets):
    plugins = []
    for t in targets:
        if _KspPluginInfo in t:
            # KSP plugins are handled by the KSP Kotlinc compiler plugin
            pass
        elif JavaPluginInfo in t:
            p = t[JavaPluginInfo].plugins
            if p.processor_jars:
                plugins.append(p)
        elif JavaInfo in t:
            p = t[JavaInfo].plugins
            if p.processor_jars:
                plugins.append(p)

    return plugins

def _targets_to_ksp_annotation_processors(targets):
    plugins = []
    for t in targets:
        if _KspPluginInfo in t:
            for plugin in t[_KspPluginInfo].plugins:
                plugins.append(plugin.plugins)
    return depset(plugins)

def _targets_to_annotation_processors_java_plugin_info(targets):
    return [t[JavaPluginInfo] for t in targets if JavaPluginInfo in t]

def _targets_to_ksp_options(targets):
    options = {}
    for t in targets:
        if _KspPluginInfo in t:
            for key, value in t[_KspPluginInfo].options.items():
                if key in options:
                    fail("Conflicting KSP option key '%s': defined in multiple plugins" % key)
                options[key] = value
    return options

def _targets_to_transitive_runtime_jars(targets):
    transitive = []
    for t in targets:
        if JavaPluginInfo in t:
            transitive.append(t[JavaPluginInfo].plugins.processor_jars)
        elif JavaInfo in t:
            transitive.append(t[JavaInfo].plugins.processor_jars)
        elif _KspPluginInfo in t:
            transitive.extend([plugin.plugins.processor_jars for plugin in t[_KspPluginInfo].plugins])
    return depset(transitive = transitive)

def _targets_to_ksp_transitive_runtime_jars(targets):
    transitive = []
    for t in targets:
        if _KspPluginInfo in t:
            transitive.extend([plugin.plugins.processor_jars for plugin in t[_KspPluginInfo].plugins])
    return depset(transitive = transitive)

mappers = struct(
    targets_to_annotation_processors = _targets_to_annotation_processors,
    targets_to_ksp_annotation_processors = _targets_to_ksp_annotation_processors,
    targets_to_ksp_options = _targets_to_ksp_options,
    targets_to_annotation_processors_java_plugin_info = _targets_to_annotation_processors_java_plugin_info,
    targets_to_transitive_runtime_jars = _targets_to_transitive_runtime_jars,
    targets_to_ksp_transitive_runtime_jars = _targets_to_ksp_transitive_runtime_jars,
    kt_plugin_to_processor = _kt_plugin_to_processor,
    kt_plugin_to_processorpath = _kt_plugin_to_processorpath,
)
