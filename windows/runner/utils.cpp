#include "utils.h"

#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>
#include <filesystem>

#include <iostream>

void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE *unused;
    if (freopen_s(&unused, "CONOUT$", "w", stdout)) {
      _dup2(_fileno(stdout), 1);
    }
    if (freopen_s(&unused, "CONOUT$", "w", stderr)) {
      _dup2(_fileno(stdout), 2);
    }
    std::ios::sync_with_stdio();
    FlutterDesktopResyncOutputStreams();
  }
}

std::vector<std::string> GetCommandLineArguments() {
  // Convert the UTF-16 command line arguments to UTF-8 for the Engine to use.
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }

  std::vector<std::string> command_line_arguments;

  // Skip the first argument as it's the binary name.
  for (int i = 1; i < argc; i++) {
    command_line_arguments.push_back(Utf8FromUtf16(argv[i]));
  }

  ::LocalFree(argv);

  return command_line_arguments;
}

std::string Utf8FromUtf16(const wchar_t* utf16_string) {
  if (utf16_string == nullptr) {
    return std::string();
  }
  unsigned int target_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      -1, nullptr, 0, nullptr, nullptr)
    -1; // remove the trailing null character
  int input_length = (int)wcslen(utf16_string);
  std::string utf8_string;
  if (target_length == 0 || target_length > utf8_string.max_size()) {
    return utf8_string;
  }
  utf8_string.resize(target_length);
  int converted_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      input_length, utf8_string.data(), target_length, nullptr, nullptr);
  if (converted_length == 0) {
    return std::string();
  }
  return utf8_string;
}
// Native library loading utilities implementation

bool ValidateExecutablePath(const std::string& path) {
  try {
    if (path.empty()) {
      return false;
    }
    
    std::filesystem::path exe_path(path);
    
    // Check if file exists
    if (!std::filesystem::exists(exe_path)) {
      return false;
    }
    
    // Check if it's a regular file
    if (!std::filesystem::is_regular_file(exe_path)) {
      return false;
    }
    
    // Check file size (should be at least 1MB for sing-box)
    std::error_code ec;
    auto file_size = std::filesystem::file_size(exe_path, ec);
    if (ec || file_size < 1000000) {
      return false;
    }
    
    // Check file extension
    if (exe_path.extension() != ".exe") {
      return false;
    }
    
    return true;
  } catch (const std::exception&) {
    return false;
  }
}

bool CheckSystemLibraryAvailability() {
  try {
    // Check for required Windows system libraries
    std::vector<std::string> required_libs = {
      "kernel32.dll",
      "ws2_32.dll",
      "iphlpapi.dll",
      "wininet.dll",
      "shell32.dll",
      "advapi32.dll",
      "user32.dll"
    };
    
    for (const auto& lib : required_libs) {
      HMODULE handle = LoadLibraryA(lib.c_str());
      if (handle == nullptr) {
        std::cerr << "Failed to load required system library: " << lib << std::endl;
        return false;
      }
      FreeLibrary(handle);
    }
    
    return true;
  } catch (const std::exception& e) {
    std::cerr << "Exception checking system library availability: " << e.what() << std::endl;
    return false;
  }
}

std::string GetApplicationDirectory() {
  try {
    char exe_path[MAX_PATH];
    if (!GetModuleFileNameA(nullptr, exe_path, MAX_PATH)) {
      return "";
    }
    
    std::filesystem::path app_path(exe_path);
    return app_path.parent_path().string();
  } catch (const std::exception&) {
    return "";
  }
}

std::vector<std::string> GetLibrarySearchPaths() {
  std::vector<std::string> search_paths;
  
  try {
    std::string app_dir = GetApplicationDirectory();
    if (app_dir.empty()) {
      return search_paths;
    }
    
    std::filesystem::path base_path(app_dir);
    
    // Add various potential library locations
    search_paths.push_back(app_dir);
    search_paths.push_back((base_path / "bin").string());
    search_paths.push_back((base_path / "lib").string());
    search_paths.push_back((base_path / "native").string());
    search_paths.push_back((base_path / "sing-box").string());
    
    // Add system paths
    char system_path[MAX_PATH];
    if (GetSystemDirectoryA(system_path, MAX_PATH)) {
      search_paths.push_back(std::string(system_path));
    }
    
    // Add Windows directory
    char windows_path[MAX_PATH];
    if (GetWindowsDirectoryA(windows_path, MAX_PATH)) {
      search_paths.push_back(std::string(windows_path));
    }
    
    // Add PATH environment variable directories
    char path_env[32768]; // Large buffer for PATH
    DWORD path_len = GetEnvironmentVariableA("PATH", path_env, sizeof(path_env));
    if (path_len > 0 && path_len < sizeof(path_env)) {
      std::string path_str(path_env);
      size_t pos = 0;
      while ((pos = path_str.find(';')) != std::string::npos) {
        std::string path_entry = path_str.substr(0, pos);
        if (!path_entry.empty()) {
          search_paths.push_back(path_entry);
        }
        path_str.erase(0, pos + 1);
      }
      if (!path_str.empty()) {
        search_paths.push_back(path_str);
      }
    }
    
  } catch (const std::exception& e) {
    std::cerr << "Exception getting library search paths: " << e.what() << std::endl;
  }
  
  return search_paths;
}