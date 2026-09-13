// Shared implementation details of the native Java launcher.
#ifndef RULES_KOTLIN_NATIVE_JAVA_LAUNCHER_H_
#define RULES_KOTLIN_NATIVE_JAVA_LAUNCHER_H_

#include <cstdint>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <memory>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#include "rules_cc/cc/runfiles/runfiles.h"

using rules_cc::cc::runfiles::Runfiles;
namespace fs = std::filesystem;

static std::string Env(const char *name) {
  const char *value = std::getenv(name);
  return value ? value : "";
}

// launcher_maker appends NUL-separated key=value records and an int64 size.
static std::map<std::string, std::string>
ReadConfig(const fs::path &executable) {
  std::ifstream input(executable, std::ios::binary | std::ios::ate);
  const auto end = input.tellg();
  int64_t size = 0;
  if (end < static_cast<std::streamoff>(sizeof(size))) {
    throw std::runtime_error("missing launch data");
  }
  input.seekg(end - static_cast<std::streamoff>(sizeof(size)));
  input.read(reinterpret_cast<char *>(&size), sizeof(size));
  if (size <= 0 || size > end - static_cast<std::streamoff>(sizeof(size))) {
    throw std::runtime_error("invalid launch data size");
  }
  input.seekg(end - static_cast<std::streamoff>(sizeof(size)) - size);
  std::string data(size, '\0');
  if (!input.read(data.data(), size))
    throw std::runtime_error("cannot read launch data");
  std::istringstream records(data);
  std::map<std::string, std::string> config;
  for (std::string record; std::getline(records, record, '\0');) {
    const auto equal = record.find('=');
    if (equal == std::string::npos || equal == 0 ||
        !config.emplace(record.substr(0, equal), record.substr(equal + 1))
             .second) {
      throw std::runtime_error("invalid launch data record");
    }
  }
  return config;
}

static std::string Resolve(const Runfiles &runfiles, const std::string &path) {
  const fs::path resolved = fs::u8path(runfiles.Rlocation(path));
  if (resolved.empty() || !fs::exists(resolved)) {
    throw std::runtime_error("missing runfile: " + path);
  }
  return fs::absolute(resolved).u8string();
}

static std::string NativeLibraryPath(const Runfiles &runfiles,
                                     const std::string &libraries,
                                     char separator) {
  std::istringstream input(libraries);
  std::set<std::string> seen;
  std::string flag = "-Djava.library.path=";
  for (std::string library; std::getline(input, library, '\t');) {
    const std::string directory =
        fs::u8path(Resolve(runfiles, library)).parent_path().generic_u8string();
    if (!seen.insert(directory).second)
      continue;
    if (seen.size() > 1)
      flag += separator;
    flag += directory;
  }
  return flag;
}

// _wspawnv joins its arguments without quoting; use the Windows CRT convention.
static std::wstring Quote(const std::wstring &value) {
  std::wstring result = L"\"";
  size_t slashes = 0;
  for (wchar_t c : value) {
    if (c == L'\\') {
      ++slashes;
    } else {
      result.append(c == L'"' ? 2 * slashes + 1 : slashes, L'\\');
      result += c;
      slashes = 0;
    }
  }
  result.append(2 * slashes, L'\\');
  return result + L'"';
}

#endif
