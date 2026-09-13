// Tests the Windows launcher's portable path resolution and launch-data logic.
#include "kotlin/internal/jvm/native_java_launcher.h"

#include <cassert>

int main() {
  const fs::path root = fs::u8path(Env("TEST_TMPDIR"));
  const fs::path first = root / "first directory";
  const fs::path second = root / "second directory";
  fs::create_directories(first);
  fs::create_directories(second);
  std::ofstream(first / "native.dll").put('x');
  std::ofstream(second / "other.dll").put('x');
  const auto manifest = root / "MANIFEST";
  std::ofstream(manifest) << "_main/native.dll "
                          << (first / "native.dll").u8string()
                          << "\nexternal+/other.dll "
                          << (second / "other.dll").u8string() << '\n';
  std::string error;
  std::unique_ptr<Runfiles> runfiles(
      Runfiles::Create("", manifest.u8string(), "", &error));
  assert(runfiles);
  const std::string libraries =
      "_main/native.dll\texternal+/other.dll\t_main/native.dll";
  for (char separator : {':', ';'}) {
    assert(NativeLibraryPath(*runfiles, libraries, separator) ==
           "-Djava.library.path=" + first.generic_u8string() + separator +
               second.generic_u8string());
  }
  bool failed = false;
  try {
    Resolve(*runfiles, "_main/missing.dll");
  } catch (const std::runtime_error &) {
    failed = true;
  }
  assert(failed);

  // Empty arguments, spaces, embedded quotes and trailing backslashes survive
  // the CRT's command-line parser when passed through _wspawnv.
  assert(Quote(L"") == L"\"\"");
  assert(Quote(L"a b") == L"\"a b\"");
  assert(Quote(L"a\"b") == L"\"a\\\"b\"");
  assert(Quote(L"C:\\with spaces\\") == L"\"C:\\with spaces\\\\\"");

  const auto executable = root / "launcher.exe";
  std::string data = "java_bin_path=jdk/bin/java.exe";
  data += '\0';
  data += "native_libraries=" + libraries;
  data += '\0';
  const int64_t size = data.size();
  std::ofstream out(executable, std::ios::binary);
  out << "binary prefix" << data;
  out.write(reinterpret_cast<const char *>(&size), sizeof(size));
  out.close();
  assert(ReadConfig(executable).at("native_libraries") == libraries);
  assert(ReadConfig(executable).at("java_bin_path") == "jdk/bin/java.exe");
  std::ofstream(executable, std::ios::binary) << "truncated";
  failed = false;
  try {
    ReadConfig(executable);
  } catch (const std::runtime_error &) {
    failed = true;
  }
  assert(failed);
}
