#ifndef NETWORK_CHANGE_DETECTOR_H_
#define NETWORK_CHANGE_DETECTOR_H_

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <iphlpapi.h>
#include <netlistmgr.h>
#include <string>
#include <memory>
#include <atomic>
#include <thread>
#include <mutex>
#include <vector>
#include <functional>
#include <chrono>
#include <queue>

#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "ws2_32.lib")

// Forward declaration
class SingboxManager;

enum class NetworkState {
    Unknown,
    Disconnected,
    ConnectedNoInternet,
    ConnectedWifi,
    ConnectedEthernet,
    ConnectedOther
};

enum class ConnectionHealth {
    Unknown,
    Good,
    Poor,
    Disconnected
};

enum class ReconnectionStatus {
    Idle,
    Attempting,
    Success,
    Failed
};

struct NetworkInfo {
    std::string adapter_name;
    std::string adapter_description;
    bool is_connected;
    bool has_internet;
    bool is_wifi;
    bool is_ethernet;
    DWORD interface_index;
    std::string ip_address;
    std::string gateway;
    DWORD link_speed; // in bps
};

struct ReconnectionAttempt {
    int attempt_number;
    std::chrono::steady_clock::time_point timestamp;
    std::string reason;
    bool success;
};

class NetworkChangeDetector {
public:
    NetworkChangeDetector(SingboxManager* singbox_manager);
    ~NetworkChangeDetector();

    // Core monitoring methods
    bool StartMonitoring(const std::string& vpn_config_json);
    void StopMonitoring();
    bool IsMonitoring() const;

    // Network state access
    NetworkState GetNetworkState() const;
    ConnectionHealth GetConnectionHealth() const;
    ReconnectionStatus GetReconnectionStatus() const;
    std::vector<NetworkInfo> GetNetworkInterfaces() const;
    NetworkInfo GetActiveNetworkInterface() const;

    // Manual control
    void TriggerReconnection();
    void ResetReconnectionAttempts();

    // Configuration
    void SetReconnectionEnabled(bool enabled);
    void SetHealthCheckInterval(int interval_ms);
    void SetMaxRetryAttempts(int max_attempts);

    // Callbacks
    void SetNetworkStateCallback(std::function<void(NetworkState)> callback);
    void SetConnectionHealthCallback(std::function<void(ConnectionHealth)> callback);
    void SetReconnectionCallback(std::function<void(ReconnectionStatus, int)> callback);

    // Statistics
    std::vector<ReconnectionAttempt> GetReconnectionHistory() const;
    int GetTotalReconnectionAttempts() const;
    std::chrono::steady_clock::time_point GetLastNetworkChange() const;

private:
    // Network monitoring
    void StartNetworkMonitorThread();
    void StopNetworkMonitorThread();
    void NetworkMonitorLoop();
    bool RegisterForNetworkNotifications();
    void UnregisterNetworkNotifications();
    
    // Health monitoring
    void StartHealthMonitorThread();
    void StopHealthMonitorThread();
    void HealthMonitorLoop();
    void CheckConnectionHealth();
    bool TestInternetConnectivity() const;
    bool TestVpnConnectivity();
    
    // Network interface monitoring
    void UpdateNetworkInterfaces();
    void DetectNetworkChanges();
    bool HasNetworkInterfaceChanged();
    std::vector<NetworkInfo> EnumerateNetworkInterfaces();
    NetworkInfo GetNetworkInterfaceInfo(DWORD interface_index);
    
    // Reconnection logic
    void AttemptReconnection(const std::string& reason);
    void ScheduleReconnectionAttempt(const std::string& reason);
    DWORD CalculateBackoffDelay(int attempt_number);
    void RecordReconnectionAttempt(int attempt_number, const std::string& reason, bool success);
    
    // State management
    void UpdateNetworkState();
    void UpdateConnectionHealth(ConnectionHealth new_health);
    void UpdateReconnectionStatus(ReconnectionStatus new_status);
    void NotifyNetworkStateChange(NetworkState new_state);
    void NotifyConnectionHealthChange(ConnectionHealth new_health);
    void NotifyReconnectionStatusChange(ReconnectionStatus new_status, int attempt_number);
    
    // Utility methods
    std::string NetworkStateToString(NetworkState state) const;
    std::string ConnectionHealthToString(ConnectionHealth health) const;
    std::string ReconnectionStatusToString(ReconnectionStatus status) const;
    bool IsNetworkConnected() const;
    bool HasInternetAccess() const;
    
    // Windows-specific network detection
    bool InitializeWinsock();
    void CleanupWinsock();
    DWORD GetActiveNetworkInterfaceIndex();
    std::string GetInterfaceTypeString(DWORD interface_type);
    
    // Member variables
    SingboxManager* singbox_manager_;
    std::string vpn_config_json_;
    
    // State
    mutable std::mutex state_mutex_;
    NetworkState current_network_state_;
    ConnectionHealth current_connection_health_;
    ReconnectionStatus current_reconnection_status_;
    std::vector<NetworkInfo> network_interfaces_;
    NetworkInfo active_interface_;
    std::chrono::steady_clock::time_point last_network_change_;
    
    // Monitoring threads
    std::atomic<bool> is_monitoring_;
    std::atomic<bool> network_monitor_running_;
    std::atomic<bool> health_monitor_running_;
    std::thread network_monitor_thread_;
    std::thread health_monitor_thread_;
    
    // Reconnection state
    std::atomic<bool> reconnection_enabled_;
    std::atomic<bool> is_reconnecting_;
    std::atomic<int> retry_attempts_;
    std::atomic<int> max_retry_attempts_;
    std::queue<ReconnectionAttempt> reconnection_history_;
    mutable std::mutex reconnection_mutex_;
    
    // Configuration
    std::atomic<int> health_check_interval_ms_;
    std::atomic<bool> winsock_initialized_;
    
    // Callbacks
    mutable std::mutex callback_mutex_;
    std::function<void(NetworkState)> network_state_callback_;
    std::function<void(ConnectionHealth)> connection_health_callback_;
    std::function<void(ReconnectionStatus, int)> reconnection_callback_;
    
    // Windows handles
    HANDLE network_change_event_;
    OVERLAPPED network_change_overlapped_;
    
    // Constants
    static constexpr int DEFAULT_HEALTH_CHECK_INTERVAL_MS = 30000; // 30 seconds
    static constexpr int DEFAULT_MAX_RETRY_ATTEMPTS = 10;
    static constexpr DWORD INITIAL_RETRY_DELAY_MS = 1000; // 1 second
    static constexpr DWORD MAX_RETRY_DELAY_MS = 60000; // 1 minute
    static constexpr double BACKOFF_MULTIPLIER = 2.0;
    static constexpr int CONNECTION_TIMEOUT_MS = 10000; // 10 seconds
    static constexpr int MAX_RECONNECTION_HISTORY = 100;
    static constexpr int NETWORK_MONITOR_INTERVAL_MS = 5000; // 5 seconds
};

#endif // NETWORK_CHANGE_DETECTOR_H_