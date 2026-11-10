// Copyright 2026 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Windows only. Bazel's Windows Java launcher passes JVM flags through
// unexpanded, so unlike the Unix stub script it cannot point java.library.path
// into the runfiles. For a kt_jvm_binary or kt_jvm_test with native libraries
// it runs this program in place of java.exe instead. This program resolves the
// runfiles named by
//   -Drules_kotlin.java=<java.exe>
//   -Drules_kotlin.native_library=<library>  (once per library)
// and runs java.exe with -Djava.library.path=<the libraries' directories>
// followed by its own command line, unchanged, so that a java.library.path the
// user passes still wins.

#include <windows.h>

#include <cstdio>
#include <cwchar>
#include <memory>
#include <string>

#include "rules_cc/cc/runfiles/runfiles.h"

using rules_cc::cc::runfiles::Runfiles;

namespace {

std::string Utf8(const std::wstring& s) {
  if (s.empty()) return std::string();
  const int size = WideCharToMultiByte(CP_UTF8, 0, s.data(), (int)s.size(),
                                       nullptr, 0, nullptr, nullptr);
  std::string result(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, s.data(), (int)s.size(), &result[0], size,
                      nullptr, nullptr);
  return result;
}

std::wstring Wide(const std::string& s) {
  if (s.empty()) return std::wstring();
  const int size =
      MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), nullptr, 0);
  std::wstring result(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), &result[0], size);
  return result;
}

int Fail(const std::wstring& message) {
  fwprintf(stderr, L"rules_kotlin native_java_launcher: %ls\n",
           message.c_str());
  return 1;
}

bool StartsWith(const std::wstring& s, const std::wstring& prefix) {
  return s.compare(0, prefix.size(), prefix) == 0;
}

// Skips the program name, which ends at its closing quote if it starts with
// one, otherwise at the first space or tab.
const wchar_t* SkipProgramName(const wchar_t* command_line) {
  if (*command_line == L'"') {
    const wchar_t* end = wcschr(command_line + 1, L'"');
    return end ? end + 1 : L"";
  }
  while (*command_line && *command_line != L' ' && *command_line != L'\t') {
    ++command_line;
  }
  return command_line;
}

}  // namespace

int wmain(int argc, wchar_t** argv) {
  const std::wstring java_flag = L"-Drules_kotlin.java=";
  const std::wstring library_flag = L"-Drules_kotlin.native_library=";

  // Bazel's launcher exports RUNFILES_MANIFEST_FILE, or RUNFILES_DIR as
  // <launcher>.runfiles. Without a runfiles tree that directory may not exist,
  // but the runfiles library then finds <launcher>.runfiles_manifest.
  const wchar_t* runfiles_dir = _wgetenv(L"RUNFILES_DIR");
  std::wstring launcher = runfiles_dir ? runfiles_dir : L"";
  const std::wstring suffix = L".runfiles";
  if (launcher.size() > suffix.size() &&
      launcher.compare(launcher.size() - suffix.size(), suffix.size(),
                       suffix) == 0) {
    launcher.resize(launcher.size() - suffix.size());
  }
  std::string error;
  std::unique_ptr<Runfiles> runfiles(Runfiles::Create(Utf8(launcher), &error));
  if (!runfiles) return Fail(Wide(error));

  std::wstring java;
  std::wstring library_path;
  for (int i = 1; i < argc; ++i) {
    const std::wstring arg = argv[i];
    const bool is_java = StartsWith(arg, java_flag);
    if (!is_java && !StartsWith(arg, library_flag)) continue;
    const std::wstring name =
        arg.substr((is_java ? java_flag : library_flag).size());
    const std::wstring path = Wide(runfiles->Rlocation(Utf8(name)));
    if (path.empty() ||
        GetFileAttributesW(path.c_str()) == INVALID_FILE_ATTRIBUTES) {
      return Fail(L"cannot find " + name + L" in the runfiles");
    }
    if (is_java) {
      java = path;
      continue;
    }
    const std::wstring dir = path.substr(0, path.find_last_of(L"/\\"));
    if ((L";" + library_path + L";").find(L";" + dir + L";") ==
        std::wstring::npos) {
      library_path += (library_path.empty() ? L"" : L";") + dir;
    }
  }
  if (java.empty()) return Fail(L"missing " + java_flag);

  // Windows paths contain no quotes, and neither of these ends in a backslash,
  // so plain quoting suffices. The rest of the command line was escaped by
  // Bazel's launcher and is passed on as is.
  std::wstring command_line = L"\"" + java + L"\" \"-Djava.library.path=" +
                              library_path + L"\"" +
                              SkipProgramName(GetCommandLineW());
  STARTUPINFOW startup_info = {sizeof(startup_info)};
  PROCESS_INFORMATION process = {};
  if (!CreateProcessW(nullptr, &command_line[0], nullptr, nullptr,
                      /* bInheritHandles */ TRUE, 0, nullptr, nullptr,
                      &startup_info, &process)) {
    return Fail(L"cannot run " + java);
  }
  WaitForSingleObject(process.hProcess, INFINITE);
  DWORD exit_code = 1;
  GetExitCodeProcess(process.hProcess, &exit_code);
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
  return (int)exit_code;
}
