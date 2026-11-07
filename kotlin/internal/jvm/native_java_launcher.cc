// Copyright 2026 The Bazel Authors. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy at https://www.apache.org/licenses/LICENSE-2.0

// The Windows Bazel launcher resolves the JVM and classpath, but does not
// expand runfiles in JVM flags. Act as its java.exe, adding the native search
// path before the original arguments so user JVM flags still take precedence.
#include "native_java_launcher.h"

#ifdef _WIN32
#include <process.h>
#include <windows.h>
#else
#include <unistd.h>
#endif

#ifdef _WIN32
static std::wstring Wide(const std::string &value) {
  const int size =
      MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                          static_cast<int>(value.size()), nullptr, 0);
  if (!size && !value.empty())
    throw std::runtime_error("invalid UTF-8 path");
  std::wstring result(size, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), result.data(), size);
  return result;
}

#endif

#ifdef _WIN32
int wmain(int argc, wchar_t **argv) {
#else
int main(int argc, char **argv) {
#endif
  try {
#ifdef _WIN32
    std::wstring executable(32768, L'\0');
    const DWORD length =
        GetModuleFileNameW(nullptr, executable.data(), executable.size());
    if (!length || length == executable.size())
      throw std::runtime_error("cannot locate launcher");
    executable.resize(length);
#else
    const fs::path executable = argv[0];
#endif
    const auto config = ReadConfig(executable);
    // The outer Java launcher sets JAVA_RUNFILES even in manifest-only mode.
    const std::string root = Env("JAVA_RUNFILES");
    const std::string outer =
        root.size() >= 9 && root.substr(root.size() - 9) == ".runfiles"
            ? root.substr(0, root.size() - 9)
            : "";
    std::string error;
    std::unique_ptr<Runfiles> runfiles(Runfiles::Create(
        outer, Env("RUNFILES_MANIFEST_FILE"),
        Env("RUNFILES_DIR").empty() ? root : Env("RUNFILES_DIR"), &error));
    if (!runfiles)
      throw std::runtime_error(error);
    const std::string java = Resolve(*runfiles, config.at("java_bin_path"));
    const std::string flag =
        NativeLibraryPath(*runfiles, config.at("native_libraries"),
#ifdef _WIN32
                          ';'
#else
                          ':'
#endif
        );
#ifdef _WIN32
    std::vector<std::wstring> arguments = {Quote(Wide(java)),
                                           Quote(Wide(flag))};
    for (int i = 1; i < argc; ++i)
      arguments.push_back(Quote(argv[i]));
    std::vector<const wchar_t *> pointers;
    for (const auto &arg : arguments)
      pointers.push_back(arg.c_str());
    pointers.push_back(nullptr);
    const auto result = _wspawnv(_P_WAIT, Wide(java).c_str(), pointers.data());
    if (result == -1)
      throw std::runtime_error("cannot start Java");
    return static_cast<int>(result);
#else
    std::vector<const char *> arguments = {java.c_str(), flag.c_str()};
    for (int i = 1; i < argc; ++i)
      arguments.push_back(argv[i]);
    arguments.push_back(nullptr);
    execv(java.c_str(), const_cast<char *const *>(arguments.data()));
    throw std::runtime_error("cannot start Java");
#endif
  } catch (const std::exception &error) {
    std::cerr << "Kotlin native launcher: " << error.what() << '\n';
    return 1;
  }
}
