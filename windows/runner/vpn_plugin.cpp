#include "vpn_plugin.h"
#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <wincred.h>
#include <iphlpapi.h>
#include <memory>
#include <string>
#include <map>
#include <thread>
#include <mutex>
#include <atomic>
#include <chrono>

#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "iphlpapi.lib")

namespace {

class VpnPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  VpnPlugin();
  virtual ~VpnPlugin();

 private:
  // Method channel handlers
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // VPN control methods
  void Connect(const flutter::EncodableMap& config,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Disconnect(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetStatus(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetNetworkStats(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HasVpnPermission(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void RequestVpnPermission(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Configuration methods
  void ValidateConfiguration(const flutter::EncodableMap& config,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SaveConfiguration(const flutter::EncodableMap& config,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void LoadConfigurations(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void DeleteConfiguration(const std::string& id,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void LoadConfiguration(const std::string& id,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void UpdateConfiguration(const flutter::EncodableMap& config,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void DeleteAllConfigurations(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void IsSecureStorageAvailable(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetStorageInfo(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Enhanced secure storage methods
  void SaveSecureData(const flutter::EncodableMap& args,
                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void LoadSecureData(const std::string& key,
                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void DeleteSecureData(const std::string& key,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Internal VPN management
  bool StartVpnConnection(const flutter::EncodableMap& config);
  bool StopVpnConnection();
  void UpdateConnectionStatus();
  void MonitorConnection();
  
  // Singbox integration
  bool InitializeSingbox();
  void CleanupSingbox();
  bool StartSingboxCore(const std::string& config_json);
  bool StopSingboxCore();
  
  // System tray integration
  void InitializeSystemTray();
  void CleanupSystemTray();
  static LRESULT CALLBACK TrayWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);
  
  // Network statistics
  void UpdateNetworkStats();
  flutter::EncodableMap GetCurrentNetworkStats();
  
  // Secure storage
  bool SaveSecureData(const std::string& key, const std::string& data);
  std::string LoadSecureData(const std::string& key);
  bool DeleteSecureData(const std::string& key);
  
  // Utility methods
  std::string GenerateConfigJson(const flutter::EncodableMap& config);
  flutter::EncodableMap CreateStatusMap();
  flutter::EncodableMap CreateErrorMap(const std::string& message, const std::string& code = "");
  bool IsAdministrator();
  bool RequestAdministratorPrivileges();

  // Member variables
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> status_channel_;
  std::atomic<bool> is_connected_{false};
  std::atomic<bool> is_connecting_{false};
  std::atomic<bool> monitoring_active_{false};
  std::thread monitor_thread_;
  std::mutex status_mutex_;
  
  // Connection state
  std::string current_server_;
  std::chrono::steady_clock::time_point connection_start_time_;
  std::string last_error_;
  
  // Network statistics
  uint64_t bytes_received_{0};
  uint64_t bytes_sent_{0};
  uint64_t packets_received_{0};
  uint64_t packets_sent_{0};
  std::chrono::steady_clock::time_point last_stats_update_;
  
  // System tray
  HWND tray_window_{nullptr};
  NOTIFYICONDATA tray_icon_data_{};
  static constexpr UINT WM_TRAYICON = WM_USER + 1;
  static constexpr UINT TRAY_ICON_ID = 1;
  
  // Singbox process handle
  HANDLE singbox_process_{nullptr};
  DWORD singbox_process_id_{0};
};

// Static instance for system tray callback
static VpnPlugin* g_plugin_instance = nullptr;

void VpnPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "vpn_control",
          &flutter::StandardMethodCodec::GetInstance());

  // Create status event channel
  auto status_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "vpn_status",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<VpnPlugin>();
  
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  plugin->channel_ = std::move(channel);
  plugin->status_channel_ = std::move(status_channel);
  g_plugin_instance = plugin.get();
  
  registrar->AddPlugin(std::move(plugin));
}

VpnPlugin::VpnPlugin() {
  InitializeSingbox();
  InitializeSystemTray();
  
  // Start monitoring thread
  monitoring_active_ = true;
  monitor_thread_ = std::thread(&VpnPlugin::MonitorConnection, this);
}

VpnPlugin::~VpnPlugin() {
  monitoring_active_ = false;
  if (monitor_thread_.joinable()) {
    monitor_thread_.join();
  }
  
  StopVpnConnection();
  CleanupSingbox();
  CleanupSystemTray();
  
  if (g_plugin_instance == this) {
    g_plugin_instance = nullptr;
  }
}

void VpnPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  const std::string& method = method_call.method_name();
  
  if (method == "connect") {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      Connect(*arguments, std::move(result));
    } else {
      result->Error("INVALID_ARGUMENTS", "Configuration map required");
    }
  } else if (method == "disconnect") {
    Disconnect(std::move(result));
  } else if (method == "getStatus") {
    GetStatus(std::move(result));
  } else if (method == "getNetworkStats") {
    GetNetworkStats(std::move(result));
  } else if (method == "hasVpnPermission") {
    HasVpnPermission(std::move(result));
  } else if (method == "requestVpnPermission") {
    RequestVpnPermission(std::move(result));
  } else if (method == "validateConfiguration") {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      ValidateConfiguration(*arguments, std::move(result));
    } else {
      result->Error("INVALID_ARGUMENTS", "Configuration map required");
    }
  } else if (method == "saveConfiguration") {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      SaveConfiguration(*arguments, std::move(result));
    } else {
      result->Error("INVALID_ARGUMENTS", "Configuration map required");
    }
  } else if (method == "loadConfigurations") {
    LoadConfigurations(std::move(result));
  } else if (method == "deleteConfiguration") {
    const auto* arguments = std::get_if<std::string>(method_call.arguments());
    if (arguments) {
      DeleteConfiguration(*arguments, std::move(result));
    } else {
      result->Error("INVALID_ARGUMENTS", "Configuration ID string required");
    }
  } else if (method == "loadConfiguration") {
    const auto* arguments = std::get_if<std::string>(method_call.arguments());
    if (arguments) {
      LoadConfiguration(*arguments, std::move(result));
    } else {
      result->Error("INVALID_ARGUMENTS", "Configuration ID string required");
    }
  } else if (method == "updateConfiguration") {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      UpdateConfiguration(*arguments, std::move(result));
    } else {
      result->Error("INVALID_ARGUMENTS", "Configuration map required");
    }
  } else if (method == "deleteAllConfigurations") {
    DeleteAllConfigurations(std::move(result));
  } else if (method == "isSecureStorageAvailable") {
    IsSecureStorageAvailable(std::move(result));
  } else if (method == "getStorageInfo") {
    GetStorageInfo(std::move(result));
  } else if (method == "saveSecureData") {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      SaveSecureData(*arguments, std::move(result));
    } else {
      result->Error("INVALID_ARGUMENTS", "Arguments map required");
    }
  } else if (method == "loadSecureData") {
    const auto* arguments = std::get_if<std::string>(method_call.arguments());
    if (arguments) {
      LoadSecureData(*arguments, std::move(result));
    } else {
      result->Error("INVALID_ARGUMENTS", "Key string required");
    }
  } else if (method == "deleteSecureData") {
    const auto* arguments = std::get_if<std::string>(method_call.arguments());
    if (arguments) {
      DeleteSecureData(*arguments, std::move(result));
    } else {
      result->Error("INVALID_ARGUMENTS", "Key string required");
    }
  } else {
    result->NotImplemented();
  }
}

// VPN Control Method Implementations
void VpnPlugin::Connect(const flutter::EncodableMap& config,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (is_connected_ || is_connecting_) {
    result->Error("ALREADY_CONNECTED", "VPN is already connected or connecting");
    return;
  }

  // Check administrator privileges
  if (!IsAdministrator()) {
    if (!RequestAdministratorPrivileges()) {
      result->Error("INSUFFICIENT_PRIVILEGES", "Administrator privileges required for VPN operations");
      return;
    }
  }

  is_connecting_ = true;
  last_error_.clear();

  // Start connection in background thread
  std::thread([this, config, result = std::move(result)]() mutable {
    bool success = StartVpnConnection(config);
    
    if (success) {
      is_connected_ = true;
      is_connecting_ = false;
      connection_start_time_ = std::chrono::steady_clock::now();
      
      // Extract server info
      auto server_it = config.find(flutter::EncodableValue("serverAddress"));
      if (server_it != config.end()) {
        current_server_ = std::get<std::string>(server_it->second);
      }
      
      result->Success(flutter::EncodableValue(true));
    } else {
      is_connecting_ = false;
      result->Error("CONNECTION_FAILED", last_error_.empty() ? "Failed to establish VPN connection" : last_error_);
    }
  }).detach();
}

void VpnPlugin::Disconnect(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!is_connected_ && !is_connecting_) {
    result->Success(flutter::EncodableValue(true));
    return;
  }

  bool success = StopVpnConnection();
  
  if (success) {
    is_connected_ = false;
    is_connecting_ = false;
    current_server_.clear();
    last_error_.clear();
    result->Success(flutter::EncodableValue(true));
  } else {
    result->Error("DISCONNECTION_FAILED", "Failed to disconnect VPN");
  }
}

void VpnPlugin::GetStatus(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::lock_guard<std::mutex> lock(status_mutex_);
  result->Success(flutter::EncodableValue(CreateStatusMap()));
}

void VpnPlugin::GetNetworkStats(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!is_connected_) {
    result->Success(flutter::EncodableValue());
    return;
  }
  
  UpdateNetworkStats();
  result->Success(flutter::EncodableValue(GetCurrentNetworkStats()));
}

void VpnPlugin::HasVpnPermission(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(IsAdministrator()));
}

void VpnPlugin::RequestVpnPermission(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool granted = RequestAdministratorPrivileges();
  result->Success(flutter::EncodableValue(granted));
}

// Configuration Method Implementations
void VpnPlugin::ValidateConfiguration(const flutter::EncodableMap& config,
                                    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Basic validation
  auto server_it = config.find(flutter::EncodableValue("serverAddress"));
  auto port_it = config.find(flutter::EncodableValue("serverPort"));
  auto protocol_it = config.find(flutter::EncodableValue("protocol"));
  
  if (server_it == config.end() || port_it == config.end() || protocol_it == config.end()) {
    result->Error("INVALID_CONFIG", "Missing required configuration fields");
    return;
  }
  
  // Validate server address
  std::string server_address = std::get<std::string>(server_it->second);
  if (server_address.empty()) {
    result->Error("INVALID_CONFIG", "Server address cannot be empty");
    return;
  }
  
  // Validate port
  int port = std::get<int>(port_it->second);
  if (port < 1 || port > 65535) {
    result->Error("INVALID_CONFIG", "Port must be between 1 and 65535");
    return;
  }
  
  result->Success(flutter::EncodableValue(true));
}

void VpnPlugin::SaveConfiguration(const flutter::EncodableMap& config,
                                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto id_it = config.find(flutter::EncodableValue("id"));
  if (id_it == config.end()) {
    result->Error("INVALID_CONFIG", "Configuration ID is required");
    return;
  }
  
  std::string config_id = std::get<std::string>(id_it->second);
  
  // Convert config to JSON string for storage
  std::string config_json = GenerateConfigJson(config);
  
  if (SaveSecureData("vpn_config_" + config_id, config_json)) {
    result->Success(flutter::EncodableValue());
  } else {
    result->Error("STORAGE_FAILED", "Failed to save configuration securely");
  }
}

void VpnPlugin::LoadConfigurations(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // For simplicity, we'll return an empty list for now
  // In a full implementation, this would enumerate stored configurations
  flutter::EncodableList configs;
  result->Success(flutter::EncodableValue(configs));
}

void VpnPlugin::DeleteConfiguration(const std::string& id,
                                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (DeleteSecureData("vpn_config_" + id)) {
    result->Success(flutter::EncodableValue(true));
  } else {
    result->Success(flutter::EncodableValue(false));
  }
}

void VpnPlugin::LoadConfiguration(const std::string& id,
                                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string config_data = LoadSecureData("vpn_config_" + id);
  if (!config_data.empty()) {
    // Parse JSON and return as map
    // For simplicity, we'll return a basic map structure
    flutter::EncodableMap config;
    config[flutter::EncodableValue("id")] = flutter::EncodableValue(id);
    config[flutter::EncodableValue("data")] = flutter::EncodableValue(config_data);
    result->Success(flutter::EncodableValue(config));
  } else {
    result->Success(flutter::EncodableValue());
  }
}

void VpnPlugin::UpdateConfiguration(const flutter::EncodableMap& config,
                                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto id_it = config.find(flutter::EncodableValue("id"));
  if (id_it == config.end()) {
    result->Error("INVALID_CONFIG", "Configuration ID is required");
    return;
  }
  
  std::string config_id = std::get<std::string>(id_it->second);
  
  // Check if configuration exists
  std::string existing_config = LoadSecureData("vpn_config_" + config_id);
  if (existing_config.empty()) {
    result->Error("CONFIG_NOT_FOUND", "Configuration not found for update");
    return;
  }
  
  // Convert config to JSON string for storage
  std::string config_json = GenerateConfigJson(config);
  
  if (SaveSecureData("vpn_config_" + config_id, config_json)) {
    result->Success(flutter::EncodableValue(true));
  } else {
    result->Error("STORAGE_FAILED", "Failed to update configuration securely");
  }
}

void VpnPlugin::DeleteAllConfigurations(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // For a full implementation, this would enumerate all stored configurations
  // and delete them. For now, we'll return a count of 0.
  result->Success(flutter::EncodableValue(0));
}

void VpnPlugin::IsSecureStorageAvailable(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Test if Windows Credential Manager is available
  bool available = true;
  
  // Try a test operation
  try {
    std::string test_key = "test_availability_" + std::to_string(GetTickCount64());
    std::string test_data = "test";
    
    if (SaveSecureData(test_key, test_data)) {
      std::string retrieved = LoadSecureData(test_key);
      DeleteSecureData(test_key);
      available = (retrieved == test_data);
    } else {
      available = false;
    }
  } catch (...) {
    available = false;
  }
  
  result->Success(flutter::EncodableValue(available));
}

void VpnPlugin::GetStorageInfo(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  flutter::EncodableMap info;
  info[flutter::EncodableValue("configurationCount")] = flutter::EncodableValue(0); // Would count actual configs
  info[flutter::EncodableValue("storageUsedBytes")] = flutter::EncodableValue(0);   // Would calculate actual usage
  info[flutter::EncodableValue("isEncrypted")] = flutter::EncodableValue(true);
  info[flutter::EncodableValue("storageLocation")] = flutter::EncodableValue("Windows Credential Manager");
  info[flutter::EncodableValue("lastBackupTime")] = flutter::EncodableValue();
  
  result->Success(flutter::EncodableValue(info));
}

// Enhanced secure storage method implementations
void VpnPlugin::SaveSecureData(const flutter::EncodableMap& args,
                              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto key_it = args.find(flutter::EncodableValue("key"));
  auto data_it = args.find(flutter::EncodableValue("data"));
  
  if (key_it == args.end() || data_it == args.end()) {
    result->Error("INVALID_ARGUMENTS", "Both key and data are required");
    return;
  }
  
  std::string key = std::get<std::string>(key_it->second);
  std::string data = std::get<std::string>(data_it->second);
  
  if (SaveSecureData(key, data)) {
    result->Success(flutter::EncodableValue());
  } else {
    result->Error("STORAGE_FAILED", "Failed to save data securely");
  }
}

void VpnPlugin::LoadSecureData(const std::string& key,
                              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string data = LoadSecureData(key);
  if (!data.empty()) {
    result->Success(flutter::EncodableValue(data));
  } else {
    result->Success(flutter::EncodableValue());
  }
}

void VpnPlugin::DeleteSecureData(const std::string& key,
                                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (DeleteSecureData(key)) {
    result->Success(flutter::EncodableValue(true));
  } else {
    result->Success(flutter::EncodableValue(false));
  }
}

// Internal VPN Management Implementation
bool VpnPlugin::StartVpnConnection(const flutter::EncodableMap& config) {
  try {
    // Generate singbox configuration
    std::string config_json = GenerateConfigJson(config);
    
    // Start singbox core
    if (!StartSingboxCore(config_json)) {
      last_error_ = "Failed to start singbox core";
      return false;
    }
    
    // Wait a moment for connection to establish
    std::this_thread::sleep_for(std::chrono::seconds(2));
    
    return true;
  } catch (const std::exception& e) {
    last_error_ = std::string("Connection error: ") + e.what();
    return false;
  }
}

bool VpnPlugin::StopVpnConnection() {
  return StopSingboxCore();
}

void VpnPlugin::UpdateConnectionStatus() {
  // This would typically check the actual connection status
  // For now, we'll use the internal state
}

void VpnPlugin::MonitorConnection() {
  while (monitoring_active_) {
    if (is_connected_) {
      UpdateNetworkStats();
      UpdateConnectionStatus();
      
      // Notify Flutter about status updates
      if (channel_) {
        std::lock_guard<std::mutex> lock(status_mutex_);
        channel_->InvokeMethod("onStatusChanged", 
                              std::make_unique<flutter::EncodableValue>(CreateStatusMap()));
      }
    }
    
    std::this_thread::sleep_for(std::chrono::seconds(1));
  }
}

// Singbox Integration Implementation
bool VpnPlugin::InitializeSingbox() {
  // Basic initialization - no Winsock needed for process management
  return true;
}

void VpnPlugin::CleanupSingbox() {
  StopSingboxCore();
}

bool VpnPlugin::StartSingboxCore(const std::string& config_json) {
  // Create temporary config file
  char temp_path[MAX_PATH];
  GetTempPathA(MAX_PATH, temp_path);
  std::string config_file = std::string(temp_path) + "singbox_config.json";
  
  HANDLE file = CreateFileA(config_file.c_str(), GENERIC_WRITE, 0, nullptr, 
                           CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return false;
  }
  
  DWORD bytes_written;
  WriteFile(file, config_json.c_str(), static_cast<DWORD>(config_json.length()), &bytes_written, nullptr);
  CloseHandle(file);
  
  // Start singbox process (assuming singbox.exe is in the application directory)
  std::string command = "singbox.exe run -c \"" + config_file + "\"";
  
  STARTUPINFOA si = {};
  PROCESS_INFORMATION pi = {};
  si.cb = sizeof(si);
  
  if (CreateProcessA(nullptr, const_cast<char*>(command.c_str()), nullptr, nullptr, 
                    FALSE, CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi)) {
    singbox_process_ = pi.hProcess;
    singbox_process_id_ = pi.dwProcessId;
    CloseHandle(pi.hThread);
    return true;
  }
  
  return false;
}

bool VpnPlugin::StopSingboxCore() {
  if (singbox_process_) {
    TerminateProcess(singbox_process_, 0);
    WaitForSingleObject(singbox_process_, 5000);
    CloseHandle(singbox_process_);
    singbox_process_ = nullptr;
    singbox_process_id_ = 0;
    return true;
  }
  return false;
}

// System Tray Integration Implementation
void VpnPlugin::InitializeSystemTray() {
  // Create hidden window for tray messages
  WNDCLASSA wc = {};
  wc.lpfnWndProc = TrayWndProc;
  wc.hInstance = GetModuleHandle(nullptr);
  wc.lpszClassName = "VpnTrayWindow";
  
  RegisterClassA(&wc);
  
  tray_window_ = CreateWindowA("VpnTrayWindow", "VPN Tray", 0, 0, 0, 0, 0, 
                              HWND_MESSAGE, nullptr, GetModuleHandle(nullptr), nullptr);
  
  if (tray_window_) {
    // Initialize tray icon
    tray_icon_data_.cbSize = sizeof(NOTIFYICONDATA);
    tray_icon_data_.hWnd = tray_window_;
    tray_icon_data_.uID = TRAY_ICON_ID;
    tray_icon_data_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    tray_icon_data_.uCallbackMessage = WM_TRAYICON;
    tray_icon_data_.hIcon = LoadIcon(nullptr, IDI_APPLICATION);
    wcscpy_s(tray_icon_data_.szTip, sizeof(tray_icon_data_.szTip)/sizeof(WCHAR), L"VPN Client");
    
    Shell_NotifyIcon(NIM_ADD, &tray_icon_data_);
  }
}

void VpnPlugin::CleanupSystemTray() {
  if (tray_window_) {
    Shell_NotifyIcon(NIM_DELETE, &tray_icon_data_);
    DestroyWindow(tray_window_);
    tray_window_ = nullptr;
  }
}

LRESULT CALLBACK VpnPlugin::TrayWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
  if (msg == WM_TRAYICON && g_plugin_instance) {
    if (lParam == WM_LBUTTONUP || lParam == WM_RBUTTONUP) {
      // Handle tray icon clicks - could show context menu or toggle connection
      // For now, just update the tray icon tooltip
      if (g_plugin_instance->is_connected_) {
        wcscpy_s(g_plugin_instance->tray_icon_data_.szTip, sizeof(g_plugin_instance->tray_icon_data_.szTip)/sizeof(WCHAR), L"VPN Client - Connected");
      } else {
        wcscpy_s(g_plugin_instance->tray_icon_data_.szTip, sizeof(g_plugin_instance->tray_icon_data_.szTip)/sizeof(WCHAR), L"VPN Client - Disconnected");
      }
      Shell_NotifyIcon(NIM_MODIFY, &g_plugin_instance->tray_icon_data_);
    }
  }
  
  return DefWindowProc(hwnd, msg, wParam, lParam);
}

// Network Statistics Implementation
void VpnPlugin::UpdateNetworkStats() {
  if (!is_connected_) return;
  
  // Get network interface statistics
  PMIB_IFTABLE pIfTable = nullptr;
  DWORD dwSize = 0;
  
  // Get the size needed
  GetIfTable(pIfTable, &dwSize, FALSE);
  pIfTable = (PMIB_IFTABLE)malloc(dwSize);
  
  if (GetIfTable(pIfTable, &dwSize, FALSE) == NO_ERROR) {
    // Find the VPN interface and update statistics
    // This is a simplified implementation
    for (DWORD i = 0; i < pIfTable->dwNumEntries; i++) {
      MIB_IFROW& row = pIfTable->table[i];
      
      // Check if this might be our VPN interface
      if (row.dwType == IF_TYPE_PPP || row.dwType == IF_TYPE_TUNNEL) {
        bytes_received_ = row.dwInOctets;
        bytes_sent_ = row.dwOutOctets;
        packets_received_ = row.dwInUcastPkts + row.dwInNUcastPkts;
        packets_sent_ = row.dwOutUcastPkts + row.dwOutNUcastPkts;
        break;
      }
    }
  }
  
  if (pIfTable) {
    free(pIfTable);
  }
  
  last_stats_update_ = std::chrono::steady_clock::now();
}

flutter::EncodableMap VpnPlugin::GetCurrentNetworkStats() {
  auto now = std::chrono::steady_clock::now();
  auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
      now - connection_start_time_).count();
  
  flutter::EncodableMap stats;
  stats[flutter::EncodableValue("bytesReceived")] = flutter::EncodableValue(static_cast<int64_t>(bytes_received_));
  stats[flutter::EncodableValue("bytesSent")] = flutter::EncodableValue(static_cast<int64_t>(bytes_sent_));
  stats[flutter::EncodableValue("connectionDuration")] = flutter::EncodableValue(static_cast<int64_t>(duration));
  stats[flutter::EncodableValue("downloadSpeed")] = flutter::EncodableValue(0.0); // Would calculate from rate
  stats[flutter::EncodableValue("uploadSpeed")] = flutter::EncodableValue(0.0);   // Would calculate from rate
  stats[flutter::EncodableValue("packetsReceived")] = flutter::EncodableValue(static_cast<int64_t>(packets_received_));
  stats[flutter::EncodableValue("packetsSent")] = flutter::EncodableValue(static_cast<int64_t>(packets_sent_));
  stats[flutter::EncodableValue("lastUpdated")] = flutter::EncodableValue(
      std::chrono::duration_cast<std::chrono::milliseconds>(
          std::chrono::system_clock::now().time_since_epoch()).count());
  
  return stats;
}

// Secure Storage Implementation
bool VpnPlugin::SaveSecureData(const std::string& key, const std::string& data) {
  // Use Windows Credential Manager for secure storage
  CREDENTIALA cred = {};
  cred.Type = CRED_TYPE_GENERIC;
  cred.TargetName = const_cast<char*>(("VpnClient_" + key).c_str());
  cred.CredentialBlobSize = static_cast<DWORD>(data.length());
  cred.CredentialBlob = reinterpret_cast<LPBYTE>(const_cast<char*>(data.c_str()));
  cred.Persist = CRED_PERSIST_LOCAL_MACHINE;
  
  return CredWriteA(&cred, 0) == TRUE;
}

std::string VpnPlugin::LoadSecureData(const std::string& key) {
  PCREDENTIALA pcred = nullptr;
  std::string target_name = "VpnClient_" + key;
  
  if (CredReadA(target_name.c_str(), CRED_TYPE_GENERIC, 0, &pcred) == TRUE) {
    std::string data(reinterpret_cast<char*>(pcred->CredentialBlob), pcred->CredentialBlobSize);
    CredFree(pcred);
    return data;
  }
  
  return "";
}

bool VpnPlugin::DeleteSecureData(const std::string& key) {
  std::string target_name = "VpnClient_" + key;
  return CredDeleteA(target_name.c_str(), CRED_TYPE_GENERIC, 0) == TRUE;
}

// Utility Method Implementations
std::string VpnPlugin::GenerateConfigJson(const flutter::EncodableMap& config) {
  // Generate a basic singbox configuration JSON
  // This is a simplified implementation - a full version would handle all protocols
  
  std::string server_address;
  int server_port = 0;
  std::string protocol;
  
  auto server_it = config.find(flutter::EncodableValue("serverAddress"));
  if (server_it != config.end()) {
    server_address = std::get<std::string>(server_it->second);
  }
  
  auto port_it = config.find(flutter::EncodableValue("serverPort"));
  if (port_it != config.end()) {
    server_port = std::get<int>(port_it->second);
  }
  
  auto protocol_it = config.find(flutter::EncodableValue("protocol"));
  if (protocol_it != config.end()) {
    protocol = std::get<std::string>(protocol_it->second);
  }
  
  // Basic singbox configuration template
  std::string config_json = R"({
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "tun0",
      "inet4_address": "172.19.0.1/30",
      "auto_route": true,
      "strict_route": false,
      "sniff": true
    }
  ],
  "outbounds": [
    {
      "type": ")" + protocol + R"(",
      "tag": "proxy",
      "server": ")" + server_address + R"(",
      "server_port": )" + std::to_string(server_port) + R"(
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [
      {
        "outbound": "direct",
        "domain": ["localhost"]
      }
    ],
    "final": "proxy"
  }
})";
  
  return config_json;
}

flutter::EncodableMap VpnPlugin::CreateStatusMap() {
  flutter::EncodableMap status;
  
  if (is_connecting_) {
    status[flutter::EncodableValue("state")] = flutter::EncodableValue("connecting");
  } else if (is_connected_) {
    status[flutter::EncodableValue("state")] = flutter::EncodableValue("connected");
  } else {
    status[flutter::EncodableValue("state")] = flutter::EncodableValue("disconnected");
  }
  
  if (!current_server_.empty()) {
    status[flutter::EncodableValue("connectedServer")] = flutter::EncodableValue(current_server_);
  }
  
  if (is_connected_) {
    auto now = std::chrono::system_clock::now();
    auto timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
        now.time_since_epoch()).count();
    status[flutter::EncodableValue("connectionStartTime")] = flutter::EncodableValue(timestamp);
    
    // Add network stats if available
    status[flutter::EncodableValue("currentStats")] = flutter::EncodableValue(GetCurrentNetworkStats());
  }
  
  if (!last_error_.empty()) {
    status[flutter::EncodableValue("lastError")] = flutter::EncodableValue(last_error_);
  }
  
  return status;
}

flutter::EncodableMap VpnPlugin::CreateErrorMap(const std::string& message, const std::string& code) {
  flutter::EncodableMap error;
  error[flutter::EncodableValue("message")] = flutter::EncodableValue(message);
  if (!code.empty()) {
    error[flutter::EncodableValue("code")] = flutter::EncodableValue(code);
  }
  return error;
}

bool VpnPlugin::IsAdministrator() {
  BOOL is_admin = FALSE;
  PSID admin_group = nullptr;
  SID_IDENTIFIER_AUTHORITY nt_authority = SECURITY_NT_AUTHORITY;
  
  if (AllocateAndInitializeSid(&nt_authority, 2, SECURITY_BUILTIN_DOMAIN_RID,
                              DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0, &admin_group)) {
    CheckTokenMembership(nullptr, admin_group, &is_admin);
    FreeSid(admin_group);
  }
  
  return is_admin == TRUE;
}

bool VpnPlugin::RequestAdministratorPrivileges() {
  // This would typically restart the application with elevated privileges
  // For now, we'll just return the current admin status
  return IsAdministrator();
}

}  // namespace

void VpnPluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
  // Create a direct plugin registrar wrapper
  auto plugin_registrar = std::make_unique<flutter::PluginRegistrarWindows>(registrar);
  VpnPlugin::RegisterWithRegistrar(plugin_registrar.get());
  plugin_registrar.release(); // Let Flutter manage the lifetime
}