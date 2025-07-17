#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <filesystem>
#include <iostream>

#include "flutter_window.h"
#include "utils.h"

// Native library loading configuration
bool ConfigureNativeLibraryPaths() {
  try {
    // Get application directory
    char exe_path[MAX_PATH];
    if (!GetModuleFileNameA(nullptr, exe_path, MAX_PATH)) {
      std::cerr << "Failed to get application path" << std::endl;
      return false;
    }
    
    std::filesystem::path app_dir = std::filesystem::path(exe_path).parent_path();
    std::cout << "Application directory: " << app_dir.string() << std::endl;
    
    // Configure sing-box executable path
    std::filesystem::path singbox_path = app_dir / "sing-box.exe";
    if (!std::filesystem::exists(singbox_path)) {
      // Try alternative locations
      std::vector<std::filesystem::path> search_paths = {
        app_dir / "bin" / "sing-box.exe",
        app_dir / "sing-box" / "sing-box.exe",
        app_dir / "native" / "sing-box.exe"
      };
      
      bool found = false;
      for (const auto& path : search_paths) {
        if (std::filesystem::exists(path)) {
          singbox_path = path;
          found = true;
          break;
        }
      }
      
      if (!found) {
        std::cerr << "Warning: sing-box.exe not found in expected locations" << std::endl;
        std::cerr << "Searched in:" << std::endl;
        std::cerr << "  - " << (app_dir / "sing-box.exe").string() << std::endl;
        for (const auto& path : search_paths) {
          std::cerr << "  - " << path.string() << std::endl;
        }
        return false;
      }
    }
    
    // Validate sing-box executable
    std::error_code ec;
    auto file_size = std::filesystem::file_size(singbox_path, ec);
    if (ec || file_size < 1000000) { // At least 1MB
      std::cerr << "Warning: sing-box executable validation failed" << std::endl;
      if (ec) {
        std::cerr << "Error: " << ec.message() << std::endl;
      } else {
        std::cerr << "File size too small: " << file_size << " bytes" << std::endl;
      }
      return false;
    }
    
    std::cout << "Native library configuration successful:" << std::endl;
    std::cout << "  - sing-box.exe: " << singbox_path.string() << " (" << file_size << " bytes)" << std::endl;
    
    // Set environment variable for runtime discovery
    std::string singbox_path_str = singbox_path.string();
    if (!SetEnvironmentVariableA("TUNNEL_MAX_SINGBOX_PATH", singbox_path_str.c_str())) {
      std::cerr << "Warning: Failed to set TUNNEL_MAX_SINGBOX_PATH environment variable" << std::endl;
    }
    
    return true;
  } catch (const std::exception& e) {
    std::cerr << "Exception in native library configuration: " << e.what() << std::endl;
    return false;
  }
}

bool ValidateNativeLibraryEnvironment() {
  try {
    // Check if required system libraries are available
    HMODULE kernel32 = GetModuleHandleA("kernel32.dll");
    HMODULE ws2_32 = LoadLibraryA("ws2_32.dll");
    HMODULE iphlpapi = LoadLibraryA("iphlpapi.dll");
    
    bool all_loaded = (kernel32 != nullptr) && (ws2_32 != nullptr) && (iphlpapi != nullptr);
    
    if (ws2_32) FreeLibrary(ws2_32);
    if (iphlpapi) FreeLibrary(iphlpapi);
    
    if (!all_loaded) {
      std::cerr << "Required system libraries not available" << std::endl;
      return false;
    }
    
    // Check Windows version compatibility
    OSVERSIONINFOA version_info = {};
    version_info.dwOSVersionInfoSize = sizeof(version_info);
    
    #pragma warning(push)
    #pragma warning(disable: 4996) // GetVersionExA is deprecated but still functional
    if (GetVersionExA(&version_info)) {
      if (version_info.dwMajorVersion < 6) { // Windows Vista or later required
        std::cerr << "Unsupported Windows version: " << version_info.dwMajorVersion 
                  << "." << version_info.dwMinorVersion << std::endl;
        return false;
      }
      std::cout << "Windows version: " << version_info.dwMajorVersion 
                << "." << version_info.dwMinorVersion << " (compatible)" << std::endl;
    }
    #pragma warning(pop)
    
    return true;
  } catch (const std::exception& e) {
    std::cerr << "Exception in native library environment validation: " << e.what() << std::endl;
    return false;
  }
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Configure native library loading before initializing COM and Flutter
  std::cout << "Configuring native library environment..." << std::endl;
  
  if (!ValidateNativeLibraryEnvironment()) {
    std::cerr << "Native library environment validation failed" << std::endl;
    MessageBoxA(nullptr, 
                "Failed to validate native library environment.\n"
                "Please ensure you have the required system libraries and Windows version.",
                "TunnelMax - Initialization Error", 
                MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }
  
  bool library_config_success = ConfigureNativeLibraryPaths();
  if (!library_config_success) {
    std::cerr << "Native library path configuration failed" << std::endl;
    MessageBoxA(nullptr, 
                "Failed to configure native library paths.\n"
                "Please ensure sing-box.exe is present in the application directory.\n\n"
                "The application will continue but VPN functionality may not work.",
                "TunnelMax - Configuration Warning", 
                MB_OK | MB_ICONWARNING);
    // Continue execution as this might not be fatal in development
  } else {
    std::cout << "Native library configuration completed successfully" << std::endl;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"tunnel_max", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
