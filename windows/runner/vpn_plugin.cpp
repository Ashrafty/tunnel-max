#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <wincred.h>
#include <iphlpapi.h>

#include "vpn_plugin.h"
#include "SingboxManager.h"
#include "StatsCollector.h"
#include "NetworkChangeDetector.h"
#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <memory>
#include <string>
#include <map>
#include <thread>
#include <mutex>
#include <atomic>
#include <chrono>
#include <algorithm>

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
  void GetRealTimeStats(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StartStatsStream(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StopStatsStream(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetDetailedStatus(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
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
  void HandleSingboxError(SingboxError error, const std::string& message);
  
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
  
  // Error code translation
  int TranslateErrorCode(SingboxError error);
  std::string TranslateErrorMessage(SingboxError error);
  std::string GetErrorSeverity(SingboxError error);
  bool IsErrorRecoverable(SingboxError error);
  
  // Real-time statistics streaming
  std::atomic<bool> stats_streaming_active_{false};

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
  
  // Singbox manager
  std::unique_ptr<SingboxManager> singbox_manager_;
  
  // Statistics collector
  std::unique_ptr<StatsCollector> stats_collector_;
  
  // Network change detector
  std::unique_ptr<NetworkChangeDetector> network_change_detector_;
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
  // Initialize SingboxManager
  singbox_manager_ = std::make_unique<SingboxManager>();
  InitializeSingbox();
  
  // Initialize StatsCollector
  if (singbox_manager_) {
    // Convert unique_ptr to shared_ptr for StatsCollector
    std::shared_ptr<SingboxManager> shared_manager(singbox_manager_.get(), [](SingboxManager*){});
    stats_collector_ = std::make_unique<StatsCollector>(shared_manager);
    
    // Set up Flutter callback for statistics updates
    stats_collector_->SetFlutterChannelCallback([this](const NetworkStats& stats) {
      if (channel_) {
        // Convert NetworkStats to Flutter-compatible map
        flutter::EncodableMap stats_map;
        stats_map[flutter::EncodableValue("bytesReceived")] = flutter::EncodableValue(static_cast<int64_t>(stats.bytes_received));
        stats_map[flutter::EncodableValue("bytesSent")] = flutter::EncodableValue(static_cast<int64_t>(stats.bytes_sent));
        stats_map[flutter::EncodableValue("downloadSpeed")] = flutter::EncodableValue(stats.download_speed);
        stats_map[flutter::EncodableValue("uploadSpeed")] = flutter::EncodableValue(stats.upload_speed);
        stats_map[flutter::EncodableValue("packetsReceived")] = flutter::EncodableValue(stats.packets_received);
        stats_map[flutter::EncodableValue("packetsSent")] = flutter::EncodableValue(stats.packets_sent);
        stats_map[flutter::EncodableValue("connectionDuration")] = flutter::EncodableValue(static_cast<int64_t>(stats.connection_duration));
        stats_map[flutter::EncodableValue("timestamp")] = flutter::EncodableValue(static_cast<int64_t>(stats.timestamp));
        
        // Notify Flutter about statistics update
        channel_->InvokeMethod("onStatsUpdate", 
                              std::make_unique<flutter::EncodableValue>(stats_map));
      }
    });
  }
  
  // Initialize NetworkChangeDetector
  if (singbox_manager_) {
    network_change_detector_ = std::make_unique<NetworkChangeDetector>(singbox_manager_.get());
    
    // Set up callbacks for network state changes
    network_change_detector_->SetNetworkStateCallback([this](NetworkState state) {
      if (channel_) {
        std::string state_str;
        switch (state) {
          case NetworkState::Disconnected: state_str = "disconnected"; break;
          case NetworkState::ConnectedNoInternet: state_str = "connected_no_internet"; break;
          case NetworkState::ConnectedWifi: state_str = "connected_wifi"; break;
          case NetworkState::ConnectedEthernet: state_str = "connected_ethernet"; break;
          case NetworkState::ConnectedOther: state_str = "connected_other"; break;
          default: state_str = "unknown"; break;
        }
        
        flutter::EncodableMap network_state_map;
        network_state_map[flutter::EncodableValue("networkState")] = flutter::EncodableValue(state_str);
        
        channel_->InvokeMethod("onNetworkStateChanged", 
                              std::make_unique<flutter::EncodableValue>(network_state_map));
      }
    });
    
    network_change_detector_->SetConnectionHealthCallback([this](ConnectionHealth health) {
      if (channel_) {
        std::string health_str;
        switch (health) {
          case ConnectionHealth::Good: health_str = "good"; break;
          case ConnectionHealth::Poor: health_str = "poor"; break;
          case ConnectionHealth::Disconnected: health_str = "disconnected"; break;
          default: health_str = "unknown"; break;
        }
        
        flutter::EncodableMap health_map;
        health_map[flutter::EncodableValue("connectionHealth")] = flutter::EncodableValue(health_str);
        
        channel_->InvokeMethod("onConnectionHealthChanged", 
                              std::make_unique<flutter::EncodableValue>(health_map));
      }
    });
    
    network_change_detector_->SetReconnectionCallback([this](ReconnectionStatus status, int attempt_number) {
      if (channel_) {
        std::string status_str;
        switch (status) {
          case ReconnectionStatus::Idle: status_str = "idle"; break;
          case ReconnectionStatus::Attempting: status_str = "attempting"; break;
          case ReconnectionStatus::Success: status_str = "success"; break;
          case ReconnectionStatus::Failed: status_str = "failed"; break;
          default: status_str = "unknown"; break;
        }
        
        flutter::EncodableMap reconnection_map;
        reconnection_map[flutter::EncodableValue("reconnectionStatus")] = flutter::EncodableValue(status_str);
        reconnection_map[flutter::EncodableValue("attemptNumber")] = flutter::EncodableValue(attempt_number);
        
        channel_->InvokeMethod("onReconnectionStatusChanged", 
                              std::make_unique<flutter::EncodableValue>(reconnection_map));
      }
    });
  }
  
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
  
  // Cleanup StatsCollector
  if (stats_collector_) {
    stats_collector_->Cleanup();
    stats_collector_.reset();
  }
  
  // Cleanup NetworkChangeDetector
  if (network_change_detector_) {
    network_change_detector_->StopMonitoring();
    network_change_detector_.reset();
  }
  
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
  
  try {
    if (method == "connect") {
      const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (arguments) {
        Connect(*arguments, std::move(result));
      } else {
        result->Error("INVALID_ARGUMENTS", "Configuration map required", 
                     flutter::EncodableValue(TranslateErrorCode(SingboxError::ConfigurationInvalid)));
      }
    } else if (method == "disconnect") {
      Disconnect(std::move(result));
    } else if (method == "getStatus") {
      GetStatus(std::move(result));
    } else if (method == "getNetworkStats") {
      GetNetworkStats(std::move(result));
    } else if (method == "getRealTimeStats") {
      GetRealTimeStats(std::move(result));
    } else if (method == "startStatsStream") {
      StartStatsStream(std::move(result));
    } else if (method == "stopStatsStream") {
      StopStatsStream(std::move(result));
    } else if (method == "getDetailedStatus") {
      GetDetailedStatus(std::move(result));
    } else if (method == "hasVpnPermission") {
      HasVpnPermission(std::move(result));
    } else if (method == "requestVpnPermission") {
      RequestVpnPermission(std::move(result));
    } else if (method == "validateConfiguration") {
      const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (arguments) {
        ValidateConfiguration(*arguments, std::move(result));
      } else {
        result->Error("INVALID_ARGUMENTS", "Configuration map required",
                     flutter::EncodableValue(TranslateErrorCode(SingboxError::ConfigurationInvalid)));
      }
    } else if (method == "saveConfiguration") {
      const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (arguments) {
        SaveConfiguration(*arguments, std::move(result));
      } else {
        result->Error("INVALID_ARGUMENTS", "Configuration map required",
                     flutter::EncodableValue(TranslateErrorCode(SingboxError::ConfigurationInvalid)));
      }
    } else if (method == "loadConfigurations") {
      LoadConfigurations(std::move(result));
    } else if (method == "deleteConfiguration") {
      const auto* arguments = std::get_if<std::string>(method_call.arguments());
      if (arguments) {
        DeleteConfiguration(*arguments, std::move(result));
      } else {
        result->Error("INVALID_ARGUMENTS", "Configuration ID string required",
                     flutter::EncodableValue(TranslateErrorCode(SingboxError::ConfigurationInvalid)));
      }
    } else if (method == "loadConfiguration") {
      const auto* arguments = std::get_if<std::string>(method_call.arguments());
      if (arguments) {
        LoadConfiguration(*arguments, std::move(result));
      } else {
        result->Error("INVALID_ARGUMENTS", "Configuration ID string required",
                     flutter::EncodableValue(TranslateErrorCode(SingboxError::ConfigurationInvalid)));
      }
    } else if (method == "updateConfiguration") {
      const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (arguments) {
        UpdateConfiguration(*arguments, std::move(result));
      } else {
        result->Error("INVALID_ARGUMENTS", "Configuration map required",
                     flutter::EncodableValue(TranslateErrorCode(SingboxError::ConfigurationInvalid)));
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
        result->Error("INVALID_ARGUMENTS", "Arguments map required",
                     flutter::EncodableValue(TranslateErrorCode(SingboxError::ConfigurationInvalid)));
      }
    } else if (method == "loadSecureData") {
      const auto* arguments = std::get_if<std::string>(method_call.arguments());
      if (arguments) {
        LoadSecureData(*arguments, std::move(result));
      } else {
        result->Error("INVALID_ARGUMENTS", "Key string required",
                     flutter::EncodableValue(TranslateErrorCode(SingboxError::ConfigurationInvalid)));
      }
    } else if (method == "deleteSecureData") {
      const auto* arguments = std::get_if<std::string>(method_call.arguments());
      if (arguments) {
        DeleteSecureData(*arguments, std::move(result));
      } else {
        result->Error("INVALID_ARGUMENTS", "Key string required",
                     flutter::EncodableValue(TranslateErrorCode(SingboxError::ConfigurationInvalid)));
      }
    } else {
      result->NotImplemented();
    }
  } catch (const std::exception& e) {
    result->Error("PLATFORM_ERROR", "Platform channel error: " + std::string(e.what()),
                 flutter::EncodableValue(TranslateErrorCode(SingboxError::UnknownError)));
  } catch (...) {
    result->Error("UNKNOWN_ERROR", "Unknown platform channel error",
                 flutter::EncodableValue(TranslateErrorCode(SingboxError::UnknownError)));
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
  
  // Get statistics from StatsCollector if available
  if (stats_collector_ && stats_collector_->IsCollecting()) {
    NetworkStats stats = stats_collector_->GetLastStats();
    
    // Convert NetworkStats to Flutter-compatible map
    flutter::EncodableMap stats_map;
    stats_map[flutter::EncodableValue("bytesReceived")] = flutter::EncodableValue(static_cast<int64_t>(stats.bytes_received));
    stats_map[flutter::EncodableValue("bytesSent")] = flutter::EncodableValue(static_cast<int64_t>(stats.bytes_sent));
    stats_map[flutter::EncodableValue("downloadSpeed")] = flutter::EncodableValue(stats.download_speed);
    stats_map[flutter::EncodableValue("uploadSpeed")] = flutter::EncodableValue(stats.upload_speed);
    stats_map[flutter::EncodableValue("packetsReceived")] = flutter::EncodableValue(stats.packets_received);
    stats_map[flutter::EncodableValue("packetsSent")] = flutter::EncodableValue(stats.packets_sent);
    stats_map[flutter::EncodableValue("connectionDuration")] = flutter::EncodableValue(static_cast<int64_t>(stats.connection_duration));
    stats_map[flutter::EncodableValue("timestamp")] = flutter::EncodableValue(static_cast<int64_t>(stats.timestamp));
    
    result->Success(flutter::EncodableValue(stats_map));
  } else {
    // Fallback to old method if StatsCollector is not available
    UpdateNetworkStats();
    result->Success(flutter::EncodableValue(GetCurrentNetworkStats()));
  }
}

void VpnPlugin::HasVpnPermission(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(IsAdministrator()));
}

void VpnPlugin::RequestVpnPermission(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool granted = RequestAdministratorPrivileges();
  result->Success(flutter::EncodableValue(granted));
}

// Enhanced VPN Control Method Implementations
void VpnPlugin::GetRealTimeStats(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!is_connected_) {
    result->Error("NOT_CONNECTED", "VPN is not connected", 
                 flutter::EncodableValue(TranslateErrorCode(SingboxError::NetworkError)));
    return;
  }
  
  try {
    // Get real-time statistics from StatsCollector
    if (stats_collector_ && stats_collector_->IsCollecting()) {
      NetworkStats current_stats = stats_collector_->GetLastStats();
      NetworkStats smoothed_stats = stats_collector_->GetSmoothedStats();
      
      flutter::EncodableMap real_time_stats;
      
      // Current statistics
      flutter::EncodableMap current_map;
      current_map[flutter::EncodableValue("bytesReceived")] = flutter::EncodableValue(static_cast<int64_t>(current_stats.bytes_received));
      current_map[flutter::EncodableValue("bytesSent")] = flutter::EncodableValue(static_cast<int64_t>(current_stats.bytes_sent));
      current_map[flutter::EncodableValue("downloadSpeed")] = flutter::EncodableValue(current_stats.download_speed);
      current_map[flutter::EncodableValue("uploadSpeed")] = flutter::EncodableValue(current_stats.upload_speed);
      current_map[flutter::EncodableValue("packetsReceived")] = flutter::EncodableValue(current_stats.packets_received);
      current_map[flutter::EncodableValue("packetsSent")] = flutter::EncodableValue(current_stats.packets_sent);
      current_map[flutter::EncodableValue("connectionDuration")] = flutter::EncodableValue(static_cast<int64_t>(current_stats.connection_duration));
      current_map[flutter::EncodableValue("timestamp")] = flutter::EncodableValue(static_cast<int64_t>(current_stats.timestamp));
      
      // Smoothed statistics for better UI display
      flutter::EncodableMap smoothed_map;
      smoothed_map[flutter::EncodableValue("downloadSpeed")] = flutter::EncodableValue(smoothed_stats.download_speed);
      smoothed_map[flutter::EncodableValue("uploadSpeed")] = flutter::EncodableValue(smoothed_stats.upload_speed);
      
      real_time_stats[flutter::EncodableValue("current")] = flutter::EncodableValue(current_map);
      real_time_stats[flutter::EncodableValue("smoothed")] = flutter::EncodableValue(smoothed_map);
      
      // Collection health information
      auto health_info = stats_collector_->GetCollectionHealth();
      flutter::EncodableMap health_map;
      for (const auto& pair : health_info) {
        health_map[flutter::EncodableValue(pair.first)] = flutter::EncodableValue(pair.second);
      }
      real_time_stats[flutter::EncodableValue("collectionHealth")] = flutter::EncodableValue(health_map);
      
      result->Success(flutter::EncodableValue(real_time_stats));
    } else {
      result->Error("STATS_UNAVAILABLE", "Statistics collection is not active",
                   flutter::EncodableValue(TranslateErrorCode(SingboxError::ResourceExhausted)));
    }
  } catch (const std::exception& e) {
    result->Error("STATS_ERROR", "Error retrieving real-time statistics: " + std::string(e.what()),
                 flutter::EncodableValue(TranslateErrorCode(SingboxError::UnknownError)));
  }
}

void VpnPlugin::StartStatsStream(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!is_connected_) {
    result->Error("NOT_CONNECTED", "VPN is not connected",
                 flutter::EncodableValue(TranslateErrorCode(SingboxError::NetworkError)));
    return;
  }
  
  try {
    if (stats_collector_) {
      if (!stats_collector_->IsCollecting()) {
        bool started = stats_collector_->Start(1000); // 1 second interval
        if (started) {
          stats_streaming_active_ = true;
          result->Success(flutter::EncodableValue(true));
        } else {
          result->Error("STREAM_START_FAILED", "Failed to start statistics streaming",
                       flutter::EncodableValue(TranslateErrorCode(SingboxError::ResourceExhausted)));
        }
      } else {
        stats_streaming_active_ = true;
        result->Success(flutter::EncodableValue(true)); // Already streaming
      }
    } else {
      result->Error("STATS_UNAVAILABLE", "Statistics collector not available",
                   flutter::EncodableValue(TranslateErrorCode(SingboxError::InitializationFailed)));
    }
  } catch (const std::exception& e) {
    result->Error("STREAM_ERROR", "Error starting statistics stream: " + std::string(e.what()),
                 flutter::EncodableValue(TranslateErrorCode(SingboxError::UnknownError)));
  }
}

void VpnPlugin::StopStatsStream(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    if (stats_collector_ && stats_collector_->IsCollecting()) {
      stats_collector_->Stop();
    }
    stats_streaming_active_ = false;
    result->Success(flutter::EncodableValue(true));
  } catch (const std::exception& e) {
    result->Error("STREAM_ERROR", "Error stopping statistics stream: " + std::string(e.what()),
                 flutter::EncodableValue(TranslateErrorCode(SingboxError::UnknownError)));
  }
}

void VpnPlugin::GetDetailedStatus(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::lock_guard<std::mutex> lock(status_mutex_);
  
  try {
    flutter::EncodableMap detailed_status = CreateStatusMap();
    
    // Add sing-box specific detailed information
    if (singbox_manager_) {
      SingboxStatus singbox_status = singbox_manager_->GetStatus();
      
      flutter::EncodableMap singbox_details;
      singbox_details[flutter::EncodableValue("isRunning")] = flutter::EncodableValue(singbox_status.is_running);
      singbox_details[flutter::EncodableValue("lastError")] = flutter::EncodableValue(static_cast<int>(singbox_status.last_error));
      singbox_details[flutter::EncodableValue("lastErrorMessage")] = flutter::EncodableValue(singbox_status.error_message);
      singbox_details[flutter::EncodableValue("translatedErrorCode")] = flutter::EncodableValue(TranslateErrorCode(singbox_status.last_error));
      singbox_details[flutter::EncodableValue("translatedErrorMessage")] = flutter::EncodableValue(TranslateErrorMessage(singbox_status.last_error));
      
      // Add error history if available
      auto error_history = singbox_manager_->GetErrorHistory();
      flutter::EncodableList error_list;
      for (const auto& error : error_history) {
        error_list.push_back(flutter::EncodableValue(error));
      }
      singbox_details[flutter::EncodableValue("errorHistory")] = flutter::EncodableValue(error_list);
      
      // Add operation timings for performance monitoring
      auto timings = singbox_manager_->GetOperationTimings();
      flutter::EncodableMap timings_map;
      for (const auto& pair : timings) {
        timings_map[flutter::EncodableValue(pair.first)] = flutter::EncodableValue(static_cast<int64_t>(pair.second));
      }
      singbox_details[flutter::EncodableValue("operationTimings")] = flutter::EncodableValue(timings_map);
      
      detailed_status[flutter::EncodableValue("singboxDetails")] = flutter::EncodableValue(singbox_details);
    }
    
    // Add network change detector information
    if (network_change_detector_ && network_change_detector_->IsMonitoring()) {
      flutter::EncodableMap network_details;
      
      NetworkState network_state = network_change_detector_->GetNetworkState();
      ConnectionHealth connection_health = network_change_detector_->GetConnectionHealth();
      ReconnectionStatus reconnection_status = network_change_detector_->GetReconnectionStatus();
      
      network_details[flutter::EncodableValue("networkState")] = flutter::EncodableValue(static_cast<int>(network_state));
      network_details[flutter::EncodableValue("connectionHealth")] = flutter::EncodableValue(static_cast<int>(connection_health));
      network_details[flutter::EncodableValue("reconnectionStatus")] = flutter::EncodableValue(static_cast<int>(reconnection_status));
      network_details[flutter::EncodableValue("totalReconnectionAttempts")] = flutter::EncodableValue(network_change_detector_->GetTotalReconnectionAttempts());
      
      // Add network interfaces information
      auto network_interfaces = network_change_detector_->GetNetworkInterfaces();
      flutter::EncodableList interfaces_list;
      for (const auto& interface : network_interfaces) {
        flutter::EncodableMap interface_map;
        interface_map[flutter::EncodableValue("name")] = flutter::EncodableValue(interface.adapter_name);
        interface_map[flutter::EncodableValue("description")] = flutter::EncodableValue(interface.adapter_description);
        interface_map[flutter::EncodableValue("isConnected")] = flutter::EncodableValue(interface.is_connected);
        interface_map[flutter::EncodableValue("hasInternet")] = flutter::EncodableValue(interface.has_internet);
        interface_map[flutter::EncodableValue("isWifi")] = flutter::EncodableValue(interface.is_wifi);
        interface_map[flutter::EncodableValue("isEthernet")] = flutter::EncodableValue(interface.is_ethernet);
        interface_map[flutter::EncodableValue("ipAddress")] = flutter::EncodableValue(interface.ip_address);
        interface_map[flutter::EncodableValue("gateway")] = flutter::EncodableValue(interface.gateway);
        interface_map[flutter::EncodableValue("linkSpeed")] = flutter::EncodableValue(static_cast<int64_t>(interface.link_speed));
        interfaces_list.push_back(flutter::EncodableValue(interface_map));
      }
      network_details[flutter::EncodableValue("networkInterfaces")] = flutter::EncodableValue(interfaces_list);
      
      detailed_status[flutter::EncodableValue("networkDetails")] = flutter::EncodableValue(network_details);
    }
    
    // Add statistics collector information
    if (stats_collector_) {
      flutter::EncodableMap stats_details;
      stats_details[flutter::EncodableValue("isCollecting")] = flutter::EncodableValue(stats_collector_->IsCollecting());
      stats_details[flutter::EncodableValue("interval")] = flutter::EncodableValue(stats_collector_->GetInterval());
      stats_details[flutter::EncodableValue("streamingActive")] = flutter::EncodableValue(stats_streaming_active_.load());
      
      // Add error information from stats collector
      auto stats_error = stats_collector_->GetLastError();
      if (stats_error != StatsCollectionError::None) {
        stats_details[flutter::EncodableValue("lastError")] = flutter::EncodableValue(static_cast<int>(stats_error));
        stats_details[flutter::EncodableValue("lastErrorMessage")] = flutter::EncodableValue(stats_collector_->GetLastErrorMessage());
      }
      
      detailed_status[flutter::EncodableValue("statsDetails")] = flutter::EncodableValue(stats_details);
    }
    
    result->Success(flutter::EncodableValue(detailed_status));
  } catch (const std::exception& e) {
    result->Error("STATUS_ERROR", "Error retrieving detailed status: " + std::string(e.what()),
                 flutter::EncodableValue(TranslateErrorCode(SingboxError::UnknownError)));
  }
}
  
  try {
    // Get real-time statistics from StatsCollector
    if (sta) {
   ;
  dStats();
      
      flutter::EncodableMap real_time_stats;
      
      // Current statistics
      fluttap;
   
  
      current_map[
      current_map[flutter::EncodableValue("u
      current_map[flutter::Encoda
      current_map[flutter::EncodableValue("packetsSent")] = flutter::Enc);
      curre
   p));
   
      // Smoothed statistics for better UI display
      flutter::EncodableMap smoothed_map;
      smoothed_map[flutte_speed);
      smoothed_map[flutter::EncodableValue("uploadSpeed")] = flutter::Encpeed);
      
    );
      real_time_stats[flutter:;
      
      // Collon
     
    p;
      for (const auto& [key, value] : health_info) {
        health_map[flutter::EncodableValue(key)] = fluttevalue);
      }
      real_time_stats[flutter::EncodableValue("collectionHealth")] = f
      
      result-ats));
    } {
   ",
  sted)));
    }
 
),
                 flutter::EncodableValue(TranslateErrorCode(SingboxErr
  }
}

void VpnPlugin::StartStatsStream(std::unique_ptr<flutter::MethodResu {
  if (!is_c {
   
  ;
    return;
  
  
  try {
  
      if (!stats_collector_->IsCollecting()) {
        bool started = stats_collector_->Start(nterval
        if
          stats_streaming_active_ = true;
   
 se {

                       flutter::EncodableValue(TranslateErrorCode(SingboxError::ResourceExhausted)));
        }
      } else {
        stats_streaming_active_ =true;
        result->Success(flutter::EncodableValue(trueming
    }
{
      result->Error("STATS_UNAVAILABLE", "Statistics colle,
                   flutter::EncodableValue(TranslateErrorCode(SingboxError::InitializationFailed)));
    }
  } catch (const std::exception& e) {
    result()),
                 flutter::EncodableValue(TranslateEr));
  }
}

void VpnPlugin::StopStatsStream(std::unique_ptr<flutter:{
  try {
    if (stats_collector_ && stats_collector_->IsCollecting()) {
      stats_collector_->Stop(
    }
    stats_streaming_active_ = false;
    result->Success(flutter::Encoue));
  } catch (const std::exception& e) {
    result->Error("STREAM_ERROR", "Error stopping statistics stream: " + std::strin
                 flutter::EncodableValue(TranslateError)));
  }
}

v {

  
  try {
    flutter::EncodableMap detailed_status = CreateStatusMa();
    
    // Add sing-box specific detailed information
    if (sin) {
   
   
      flutter::EncodableMap singbox_details;
  ;
      singbox_details[flutter::Enc);
      singbox_details[flutter::EncodableValue("lastErrorMessage")] = fluttssage);
      singbox_details[flutter::Eor));
      singbox_details[flutter::EncodableValue("translatedErrorMessage")] = f
      
   e
  ry();
      flutter::EncodableList error_list;
      for (const auto& error : error_history) {
  e(error));
      }
      singbox_details[flutter::EncodableValue("erro
      
      // Add operation timings for performance monitoring
   ();
 ap;
mings) {
        timings_map[flutter::EncodableValue(operation)] = flutter::EncodableValue(static_cast<int64_t>(timing));
      }
      singbox_details[flutter::EncodableValue("operationT;
      
 s);
  }
    
    // Add network change detector information
    if (network_change_d
  
      
      NkState();
      ConnectionHealth connection_health = network_change_detector_->GetConnectionHh();
      ReconnectionStatus reconnecti();
    
      network_details[flutter::EncodableValue(;
      network_details[flutter::EncodableValue("connectialth));
      network_details[flutter::Ens));
      network_details[flutter::EncodableValts());
      
      // Add network int
     es();
      flutter::En;
      for (const auto& {
   ap;
  _name);
        interface_map[flutter::EncodableValue("descripiption);
 ed);
net);
        interface_map[flutter::EncodableValue("isWifi")] = flutter::EncodableValue(interface.is_wifi);
        interface_map[flutterernet);
        interface_map[flutter::EncodableValue("ipAddress")] = flutter::EncodableValue(interface.ip_address);
        interface_map[flutter::EncodableValue("gateway")] = flutter::EncodableValue(interface.gateway);
        interface_map[flutter::EncodableValue("linkSpeed")] = flutter::Encodabld));
        interfaces_list.push_back(flutter::EncodableValue(interface_map));
      }
  
      
 etails);

    
    // Add statistics collector information
    if (stats_collector_) {
      flutter::EncodableMap stats_details;
      stats_details[flutter::EncodableValue("isCollecting")]cting());
  al());
      stats_details[flutter::EncodableValue("streaming
      
      // Ador
   Error();
  
        stats_details[flutter::EncodableValue("lastError")
        stats_details[flutter::EncodableValue("lastErrorMess
      }
      
      detailed_status[flutter::EncodableValue("etails);
    }
    
   ));
  {
,
                 flutter::EncodableValue(TranslateErro
  }
});or))wnError::UnknorrngboxE(SirCode())ng(e.what:stristd:tus: " + ta sailedrieving detrror ret", "EERRORATUS_>Error("STult-  res  n& e)exceptiostd::t h (cons catc }atusled_stalue(detaileVodab::Encttercess(flu->Suc resulte(stats_dcodableValulutter::En = fDetails")]stats));Message(ErrorLasttor_->Getece(stats_colldableValur::Enco flutteage")] =s_error));<int>(statstatic_castableValue(od::Enc] = flutterne) {r::NoctionErroatsColle_error != Stts  if (sta  _->GetLast_collectortatsrror = s stats_e   autocollect stats rmation from infod error);e_.load()tiving_aceamts_strlue(stacodableVar::Enutteive")] = flActrvr_->GetIntes_collectoalue(stat:EncodableV= flutter:] val")lue("intereVaodabler::Encls[flutt stats_detai   lletor_->IsColec_colatsstableValue(::Encod= flutter     }rk_due(netwoalcodableV flutter::En)] =ils"workDeta("netableValue:Encodflutter:status[iled_     detaces_list);ue(interfaleVal::Encodab flutterfaces")] =rkInter("netwoValueleEncodabutter::tails[fl  network_de  speeink_(interface.lt64_t>t<inc_cas(statieValuece.is_ethalue(interfa:EncodableVflutter:rnet")] = helue("isEt:EncodableVa:has_interrface.nte(iueValableodEnc= flutter::rnet")] nteValue("hasIabler::Encod_map[fluttefaceinter        nectis_cone(interface.luncodableVautter::E")] = flnnectedValue("isCodablecoEnlutter::ace_map[f   interf    er_descraptace.ad(interfcodableValueflutter::En] = tion")daptererface.ae(intodableValunclutter::E")] = fameue("nodableValflutter::Encface_map[er      intterface_map in:EncodableMutter:    fl s)erfacek_inttworrface : ne inteerfaces_list intbleListcodaorkInterfac->GetNetwr_detectok_change_tworrfaces = network_inteo ne autonatices informerfaempctionAttalReconne->GetTotctor__deteork_changealue(netw:EncodableVlutter: fts")] =mpnnectionAttetotalRecoue("n_statuctioonneec_cast<int>(r(staticcodableValuetter::En")] = fluionStatus"reconnectableValue(codn_hectio>(connecast<intic_e(statbleValuter::Encoda")] = flutonHealthk_state))int>(networst<c_ca(statiodableValuer::Enc)] = flutteate"St"network  onStatusnectiGetRecontector_->dechange_rk_ = netwostatusn_oealtworNettector_->Get_dengenetwork_cha= rk_state ate netwokStetworls;k_detaiap networEncodableMutter::   fl ring()) {ito_->IsMontorge_detecnetwork_chanor_ && etect  ngbox_detaillue(sieVaodablr::Enctte= flu)] xDetails"singboleValue("odabflutter::Encus[etailed_stat     dp)_maue(timingsdableValutter::Encongs")] = flimiiming] : tioperation, tnst auto& [  for (co    ap timings_mableMEncodtter::     flutionTimingstOperar_->Gex_manage= singbos timing   auto _list);orValue(errler::Encodab)] = fluttery"torHisdableValu:Encock(flutter:sh_ba.pur_list      erroetErrorHisto->Gr_x_managegboory = sin error_hist    autof availabl ihistoryr  Add erro   //t_error));x_status.lasssage(singboeErrorMeslatanlue(TrEncodableValutter::st_errx_status.laingboorCode(sslateErrlue(TranableVacod:Enutter:)] = flode"tedErrorC"translableValue(ncodaerror_mebox_status.alue(singcodableVer::Enrror)t_easx_status.l>(singboc_cast<intstatiableValue(ter::Encod] = flutor")tErras"lValue(odableing)s_runnstatus.iox_singbodableValue(tter::Enc] = flu")("isRunningeValuecodabl[flutter::Enlsdetaiox_ singb      );GetStatus(r_->gex_manangboatus = siox_stgbtatus sin   SingboxSox_manager_gbpmutex_);tatus_k(s::mutex> locstdd<_guard::lock  st>> result)leValuedabEnco::tert<flutsulodReutter::Methique_ptr<fl(std::untatusailedS::GetDetuginoid VpnPlnErrnknow::UngboxErrorode(SirCowhat()),g(e.lue(trdableVa);ult) lue>> rescodableVautter::En<flMethodResult:ror)Er:Unknownr:xErrogboSinCode(rorhatstring(e.wtd:: sm: " +treaatistics sarting st"Error stRROR", ("STREAM_E->Errorilable"avactor not  else   }    trealready s// A));  reaming",tics sttatisrt s to sta"FailedED", START_FAIL"STREAM_ror(t->Er  resul        } el       true));dableValue(ncolutter::ESuccess(f  result->      (started) {nd i 1 seco; //1000)tor_) {lectats_col  if (s}workError)))or::Netrre(SingboxEteErrorCodlaransValue(TleEncodabflutter::               ",ecteds not connD", "VPN iECTENOT_CONNror(">Er result-ted_)onnecesult)e>> raluleVdabEncoutter::lt<fl)));nownErrorr::Unko()ing(e.whattd::str " + satistics:-time staltrieving re"Error reR", TATS_ERRO>Error("Sresult-    on& e) {ceptistd::exatch (const  } cceExhaur::ResouringboxErroCode(SlateErroransleValue(Trabodter::Enc        flut         ot activection is ncs colle, "StatistiAVAILABLE"ATS_UNr("ST>Erroesult- r   else_time_stue(realValEncodabler::fluttecess(>Sucalth_map);bleValue(heEncodalutter::leValue(dabEnco::r_mahealthdableMap Encotter::lu  fth();tionHeallec_->GetColtorec_colltatsh_info = s auto healttith informa healectionothed_map)alue(smoncodableV::E = flutteroothed")]smbleValue("Encoda:_mapentue(currEncodableVal= flutter::current")] ("leValuer::Encodabs[fluttee_stat_tim  realts.upload_smoothed_sta(sdableValueots.downloadstaoothed_alue(smEncodableVter:: = flut)]loadSpeed""downValue(:Encodabler:   ats.timestam>(current_stast<int64_ttatic_calue(scodableV flutter::En] =estamp")lue("timdableVautter::Enco_map[flnt   curreduration));ection_stats.connt__t>(currencast<int64ue(static_odableValutter::Enc] = flon")tiectionDuraValue("connble::Encoda[flutternt_maps_sents.packetrrent_stateValue(cudabloceived);ckets_reats.pacurrent_stleValue(ab::Encod flutterved")] =packetsRecei"e(bleValuad_speed);s.uplourrent_statbleValue(ccodalutter::Eneed")] = fploadSpd);load_speetats.downe(current_sbleValur::Encoda")] = fluttedSpeed("downloaalueableVr::Encodflutte));.bytes_sentatsrrent_stt>(cu_cast<int64_taticableValue(stter::Encodlu")] = fntesSeeValue("bytcodablflutter::Enrent_map[  cur  ));ed_receiv.bytesent_stats>(currint64_tstatic_cast<bleValue(oda::Encflutterd")] = iveRecealue("bytesncodableVutter::Eflcurrent_map[   rent_mbleMap curncoda::Eerotheor_->GetSmoollects = stats_cat_stats smoothedNetworkSt    astStats()or_->GetL_collectatstats = st_scurrentrkStats etwo   Ng()llectin->IsCocollector_r_ && stats_lectots_colror)etworkEr:Nnnectcois not PN ED", "VONNECTT_C> rebleValue>dar::Encotteta

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
  
  // Validate protocol support using SingboxManager
  std::string protocol = std::get<std::string>(protocol_it->second);
  if (singbox_manager_) {
    auto supported_protocols = singbox_manager_->GetSupportedProtocols();
    bool protocol_supported = std::find(supported_protocols.begin(), supported_protocols.end(), protocol) != supported_protocols.end();
    
    if (!protocol_supported) {
      result->Error("UNSUPPORTED_PROTOCOL", "Protocol '" + protocol + "' is not supported by sing-box");
      return;
    }
    
    // Generate and validate sing-box configuration
    std::string config_json = GenerateConfigJson(config);
    if (!singbox_manager_->ValidateConfiguration(config_json)) {
      std::string error_msg = singbox_manager_->GetLastErrorMessage();
      result->Error("INVALID_SINGBOX_CONFIG", "Configuration validation failed: " + error_msg);
      return;
    }
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
    
    // Start statistics collection
    if (stats_collector_) {
      if (!stats_collector_->Start(1000)) { // 1 second interval
        std::cerr << "Failed to start statistics collection" << std::endl;
      }
    }
    
    // Start network change monitoring
    if (network_change_detector_) {
      if (!network_change_detector_->StartMonitoring(config_json)) {
        std::cerr << "Failed to start network change monitoring" << std::endl;
      }
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
  // Stop statistics collection
  if (stats_collector_) {
    stats_collector_->Stop();
  }
  
  return StopSingboxCore();
}

void VpnPlugin::UpdateConnectionStatus() {
  if (!singbox_manager_) {
    return;
  }
  
  // Get actual status from SingboxManager
  SingboxStatus status = singbox_manager_->GetStatus();
  bool singbox_running = singbox_manager_->IsRunning();
  
  // Update connection state based on sing-box status
  if (is_connected_ && !singbox_running) {
    // Sing-box stopped unexpectedly
    is_connected_ = false;
    is_connecting_ = false;
    last_error_ = "Sing-box process stopped unexpectedly";
  } else if (is_connecting_ && singbox_running) {
    // Connection established successfully
    is_connected_ = true;
    is_connecting_ = false;
    last_error_.clear();
  }
  
  // Update error information from SingboxManager
  if (status.last_error != SingboxError::None && last_error_.empty()) {
    last_error_ = status.error_message;
  }
}

void VpnPlugin::MonitorConnection() {
  auto last_status_update = std::chrono::steady_clock::now();
  auto last_stats_update = std::chrono::steady_clock::now();
  
  while (monitoring_active_) {
    auto now = std::chrono::steady_clock::now();
    
    if (is_connected_ || is_connecting_) {
      // Update network statistics more frequently when connected
      if (std::chrono::duration_cast<std::chrono::milliseconds>(now - last_stats_update).count() >= 1000) {
        UpdateNetworkStats();
        last_stats_update = now;
        
        // Send real-time statistics to Flutter if streaming is active
        if (stats_streaming_active_ && channel_) {
          flutter::EncodableMap current_stats = GetCurrentNetworkStats();
          channel_->InvokeMethod("onStatsUpdate", 
                                std::make_unique<flutter::EncodableValue>(current_stats));
        }
      }
      
      // Update connection status less frequently
      if (std::chrono::duration_cast<std::chrono::seconds>(now - last_status_update).count() >= 5) {
        UpdateConnectionStatus();
        last_status_update = now;
        
        // Send status updates to Flutter
        if (channel_) {
          std::lock_guard<std::mutex> lock(status_mutex_);
          flutter::EncodableMap status_map = CreateStatusMap();
          channel_->InvokeMethod("onStatusUpdate", 
                                std::make_unique<flutter::EncodableValue>(status_map));
        }
      }
    }
    
    // Check for sing-box process health
    if (singbox_manager_ && is_connected_) {
      if (!singbox_manager_->IsRunning()) {
        // Sing-box process has stopped unexpectedly
        HandleSingboxError(SingboxError::ProcessCrashed, "Sing-box process stopped unexpectedly");
      }
    }
    
    std::this_thread::sleep_for(std::chrono::milliseconds(500)); // More frequent monitoring
  }
}

// Singbox Integration Implementation
bool VpnPlugin::InitializeSingbox() {
  if (singbox_manager_) {
    // Set up process monitor callback for error handling
    singbox_manager_->SetProcessMonitorCallback([this](SingboxError error, const std::string& message) {
      HandleSingboxError(error, message);
    });
    
    bool initialized = singbox_manager_->Initialize();
    if (!initialized) {
      last_error_ = "Failed to initialize sing-box: " + singbox_manager_->GetLastErrorMessage();
    }
    return initialized;
  }
  return false;
}

void VpnPlugin::CleanupSingbox() {
  if (singbox_manager_) {
    singbox_manager_->Cleanup();
  }
}

bool VpnPlugin::StartSingboxCore(const std::string& config_json) {
  if (!singbox_manager_) {
    last_error_ = "SingboxManager not initialized";
    return false;
  }
  
  // Validate configuration before starting
  if (!singbox_manager_->ValidateConfiguration(config_json)) {
    last_error_ = "Invalid sing-box configuration: " + singbox_manager_->GetLastErrorMessage();
    return false;
  }
  
  bool started = singbox_manager_->Start(config_json);
  if (!started) {
    SingboxError error = singbox_manager_->GetLastError();
    std::string error_msg = singbox_manager_->GetLastErrorMessage();
    last_error_ = "Failed to start sing-box: " + error_msg;
    
    // Categorize error for better user feedback
    switch (error) {
      case SingboxError::PermissionDenied:
        last_error_ = "Permission denied. Please run as administrator.";
        break;
      case SingboxError::ProcessStartFailed:
        last_error_ = "Failed to start sing-box process. Check if sing-box.exe is available.";
        break;
      case SingboxError::ConfigurationInvalid:
        last_error_ = "Invalid configuration provided to sing-box.";
        break;
      case SingboxError::NetworkError:
        last_error_ = "Network error occurred while starting sing-box.";
        break;
      default:
        // Use the detailed error message from SingboxManager
        break;
    }
  }
  
  return started;
}

bool VpnPlugin::StopSingboxCore() {
  if (!singbox_manager_) {
    return true; // Already stopped
  }
  
  bool stopped = singbox_manager_->Stop();
  if (!stopped) {
    last_error_ = "Failed to stop sing-box: " + singbox_manager_->GetLastErrorMessage();
  }
  
  return stopped;
}

void VpnPlugin::HandleSingboxError(SingboxError error, const std::string& message) {
  // Handle sing-box process errors and update connection state
  std::lock_guard<std::mutex> lock(status_mutex_);
  
  // Update connection state based on error severity
  switch (error) {
    case SingboxError::ProcessCrashed:
    case SingboxError::ProcessStartFailed:
    case SingboxError::PermissionDenied:
      is_connected_ = false;
      is_connecting_ = false;
      break;
    case SingboxError::NetworkError:
    case SingboxError::ResourceExhausted:
      // These might be temporary, don't change connection state immediately
      break;
    default:
      break;
  }
  
  // Set detailed error message
  last_error_ = TranslateErrorMessage(error);
  if (!message.empty()) {
    last_error_ += " Details: " + message;
  }
  
  // Notify Flutter about the error with enhanced information
  if (channel_) {
    flutter::EncodableMap error_map;
    error_map[flutter::EncodableValue("error")] = flutter::EncodableValue(last_error_);
    error_map[flutter::EncodableValue("errorCode")] = flutter::EncodableValue(static_cast<int>(error));
    error_map[flutter::EncodableValue("translatedErrorCode")] = flutter::EncodableValue(TranslateErrorCode(error));
    error_map[flutter::EncodableValue("translatedErrorMessage")] = flutter::EncodableValue(TranslateErrorMessage(error));
    error_map[flutter::EncodableValue("nativeMessage")] = flutter::EncodableValue(message);
    error_map[flutter::EncodableValue("timestamp")] = flutter::EncodableValue(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch()).count());
    error_map[flutter::EncodableValue("severity")] = flutter::EncodableValue(GetErrorSeverity(error));
    error_map[flutter::EncodableValue("isRecoverable")] = flutter::EncodableValue(IsErrorRecoverable(error));
    
    // Add connection state information
    error_map[flutter::EncodableValue("connectionState")] = flutter::EncodableValue(
        is_connected_ ? "connected" : (is_connecting_ ? "connecting" : "disconnected"));
    
    channel_->InvokeMethod("onError", 
                          std::make_unique<flutter::EncodableValue>(error_map));
  }
  
  // Also send real-time status update
  if (channel_) {
    flutter::EncodableMap status_update = CreateStatusMap();
    channel_->InvokeMethod("onStatusUpdate", 
                          std::make_unique<flutter::EncodableValue>(status_update));
  }
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
  flutter::EncodableMap stats;
  
  if (singbox_manager_ && singbox_manager_->IsRunning()) {
    // Get statistics from SingboxManager
    NetworkStats native_stats = singbox_manager_->GetStatistics();
    
    stats[flutter::EncodableValue("bytesReceived")] = flutter::EncodableValue(static_cast<int64_t>(native_stats.bytes_received));
    stats[flutter::EncodableValue("bytesSent")] = flutter::EncodableValue(static_cast<int64_t>(native_stats.bytes_sent));
    stats[flutter::EncodableValue("connectionDuration")] = flutter::EncodableValue(static_cast<int64_t>(native_stats.connection_duration));
    stats[flutter::EncodableValue("downloadSpeed")] = flutter::EncodableValue(native_stats.download_speed);
    stats[flutter::EncodableValue("uploadSpeed")] = flutter::EncodableValue(native_stats.upload_speed);
    stats[flutter::EncodableValue("packetsReceived")] = flutter::EncodableValue(static_cast<int64_t>(native_stats.packets_received));
    stats[flutter::EncodableValue("packetsSent")] = flutter::EncodableValue(static_cast<int64_t>(native_stats.packets_sent));
    stats[flutter::EncodableValue("lastUpdated")] = flutter::EncodableValue(static_cast<int64_t>(native_stats.timestamp));
    
    // Additional status information
    stats[flutter::EncodableValue("isActive")] = flutter::EncodableValue(true);
    stats[flutter::EncodableValue("source")] = flutter::EncodableValue("singbox");
  } else {
    // Fallback to system network statistics when sing-box is not running
    auto now = std::chrono::steady_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
        now - connection_start_time_).count();
    
    stats[flutter::EncodableValue("bytesReceived")] = flutter::EncodableValue(static_cast<int64_t>(bytes_received_));
    stats[flutter::EncodableValue("bytesSent")] = flutter::EncodableValue(static_cast<int64_t>(bytes_sent_));
    stats[flutter::EncodableValue("connectionDuration")] = flutter::EncodableValue(static_cast<int64_t>(duration));
    stats[flutter::EncodableValue("downloadSpeed")] = flutter::EncodableValue(0.0);
    stats[flutter::EncodableValue("uploadSpeed")] = flutter::EncodableValue(0.0);
    stats[flutter::EncodableValue("packetsReceived")] = flutter::EncodableValue(static_cast<int64_t>(packets_received_));
    stats[flutter::EncodableValue("packetsSent")] = flutter::EncodableValue(static_cast<int64_t>(packets_sent_));
    stats[flutter::EncodableValue("lastUpdated")] = flutter::EncodableValue(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch()).count());
    
    // Additional status information
    stats[flutter::EncodableValue("isActive")] = flutter::EncodableValue(is_connected_.load());
    stats[flutter::EncodableValue("source")] = flutter::EncodableValue("system");
  }
  
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
  
  // Basic connection state
  if (is_connecting_) {
    status[flutter::EncodableValue("state")] = flutter::EncodableValue("connecting");
  } else if (is_connected_) {
    status[flutter::EncodableValue("state")] = flutter::EncodableValue("connected");
  } else {
    status[flutter::EncodableValue("state")] = flutter::EncodableValue("disconnected");
  }
  
  // Connection details
  status[flutter::EncodableValue("isConnected")] = flutter::EncodableValue(is_connected_.load());
  status[flutter::EncodableValue("isConnecting")] = flutter::EncodableValue(is_connecting_.load());
  
  if (!current_server_.empty()) {
    status[flutter::EncodableValue("connectedServer")] = flutter::EncodableValue(current_server_);
  }
  
  // Connection timing
  if (is_connected_) {
    auto now = std::chrono::system_clock::now();
    auto timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
        now.time_since_epoch()).count();
    status[flutter::EncodableValue("connectionStartTime")] = flutter::EncodableValue(timestamp);
    
    // Connection duration
    auto duration = std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::steady_clock::now() - connection_start_time_).count();
    status[flutter::EncodableValue("connectionDuration")] = flutter::EncodableValue(static_cast<int64_t>(duration));
    
    // Add network stats if available
    status[flutter::EncodableValue("currentStats")] = flutter::EncodableValue(GetCurrentNetworkStats());
  } else {
    status[flutter::EncodableValue("connectionDuration")] = flutter::EncodableValue(static_cast<int64_t>(0));
  }
  
  // Error information
  if (!last_error_.empty()) {
    status[flutter::EncodableValue("lastError")] = flutter::EncodableValue(last_error_);
  }
  
  // Sing-box specific status
  if (singbox_manager_) {
    SingboxStatus singbox_status = singbox_manager_->GetStatus();
    status[flutter::EncodableValue("singboxRunning")] = flutter::EncodableValue(singbox_manager_->IsRunning());
    status[flutter::EncodableValue("singboxError")] = flutter::EncodableValue(static_cast<int>(singbox_status.last_error));
    status[flutter::EncodableValue("singboxErrorMessage")] = flutter::EncodableValue(singbox_status.error_message);
    
    // Supported protocols
    auto protocols = singbox_manager_->GetSupportedProtocols();
    flutter::EncodableList protocol_list;
    for (const auto& protocol : protocols) {
      protocol_list.push_back(flutter::EncodableValue(protocol));
    }
    status[flutter::EncodableValue("supportedProtocols")] = flutter::EncodableValue(protocol_list);
  } else {
    status[flutter::EncodableValue("singboxRunning")] = flutter::EncodableValue(false);
    status[flutter::EncodableValue("singboxError")] = flutter::EncodableValue(static_cast<int>(SingboxError::InitializationFailed));
    status[flutter::EncodableValue("singboxErrorMessage")] = flutter::EncodableValue("SingboxManager not initialized");
    status[flutter::EncodableValue("supportedProtocols")] = flutter::EncodableValue(flutter::EncodableList{});
  }
  
  // Timestamp
  status[flutter::EncodableValue("timestamp")] = flutter::EncodableValue(
      std::chrono::duration_cast<std::chrono::milliseconds>(
          std::chrono::system_clock::now().time_since_epoch()).count());
  
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

// Error Code Translation Implementation
int VpnPlugin::TranslateErrorCode(SingboxError error) {
  switch (error) {
    case SingboxError::None:
      return 0;
    case SingboxError::InitializationFailed:
      return 1001;
    case SingboxError::ConfigurationInvalid:
      return 1002;
    case SingboxError::ProcessStartFailed:
      return 1003;
    case SingboxError::ProcessCrashed:
      return 1004;
    case SingboxError::NetworkError:
      return 1005;
    case SingboxError::PermissionDenied:
      return 1006;
    case SingboxError::ResourceExhausted:
      return 1007;
    case SingboxError::UnknownError:
    default:
      return 1999;
  }
}

std::string VpnPlugin::TranslateErrorMessage(SingboxError error) {
  switch (error) {
    case SingboxError::None:
      return "No error";
    case SingboxError::InitializationFailed:
      return "Failed to initialize sing-box core. Please check if sing-box.exe is available and accessible.";
    case SingboxError::ConfigurationInvalid:
      return "The provided VPN configuration is invalid or contains unsupported parameters.";
    case SingboxError::ProcessStartFailed:
      return "Failed to start sing-box process. Please ensure you have administrator privileges.";
    case SingboxError::ProcessCrashed:
      return "The sing-box process has crashed unexpectedly. Please check the logs for more details.";
    case SingboxError::NetworkError:
      return "A network error occurred. Please check your internet connection and server settings.";
    case SingboxError::PermissionDenied:
      return "Permission denied. Administrator privileges are required for VPN operations.";
    case SingboxError::ResourceExhausted:
      return "System resources are exhausted. Please close other applications and try again.";
    case SingboxError::UnknownError:
    default:
      return "An unknown error occurred. Please check the logs for more information.";
  }
}

std::string VpnPlugin::GetErrorSeverity(SingboxError error) {
  switch (error) {
    case SingboxError::None:
      return "info";
    case SingboxError::InitializationFailed:
    case SingboxError::ProcessStartFailed:
    case SingboxError::ProcessCrashed:
    case SingboxError::PermissionDenied:
      return "critical";
    case SingboxError::ConfigurationInvalid:
    case SingboxError::NetworkError:
      return "error";
    case SingboxError::ResourceExhausted:
      return "warning";
    case SingboxError::UnknownError:
    default:
      return "error";
  }
}

bool VpnPlugin::IsErrorRecoverable(SingboxError error) {
  switch (error) {
    case SingboxError::None:
      return true;
    case SingboxError::NetworkError:
    case SingboxError::ResourceExhausted:
      return true; // These can potentially be recovered from
    case SingboxError::ConfigurationInvalid:
      return true; // User can fix configuration
    case SingboxError::InitializationFailed:
    case SingboxError::ProcessStartFailed:
    case SingboxError::ProcessCrashed:
    case SingboxError::PermissionDenied:
      return false; // These require manual intervention
    case SingboxError::UnknownError:
    default:
      return false; // Unknown errors are assumed non-recoverable
  }
}

}  // namespace

void VpnPluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
  // Create a direct plugin registrar wrapper
  auto plugin_registrar = std::make_unique<flutter::PluginRegistrarWindows>(registrar);
  VpnPlugin::RegisterWithRegistrar(plugin_registrar.get());
  plugin_registrar.release(); // Let Flutter manage the lifetime
}