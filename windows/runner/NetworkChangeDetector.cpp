#include "NetworkChangeDetector.h"
#include "SingboxManager.h"
#include <iostream>
#include <sstream>
#include <algorithm>
#include <cmath>
#include <map>
#include <vector>
#include <wininet.h>

#pragma comment(lib, "wininet.lib")

NetworkChangeDetector::NetworkChangeDetector(SingboxManager* singbox_manager)
    : singbox_manager_(singbox_manager),
      current_network_state_(NetworkState::Unknown),
      current_connection_health_(ConnectionHealth::Unknown),
      current_reconnection_status_(ReconnectionStatus::Idle),
      is_monitoring_(false),
      network_monitor_running_(false),
      health_monitor_running_(false),
      reconnection_enabled_(true),
      is_reconnecting_(false),
      retry_attempts_(0),
      max_retry_attempts_(DEFAULT_MAX_RETRY_ATTEMPTS),
      health_check_interval_ms_(DEFAULT_HEALTH_CHECK_INTERVAL_MS),
      winsock_initialized_(false),
      network_change_event_(nullptr) {
    
    // Initialize network change event
    network_change_event_ = CreateEvent(nullptr, FALSE, FALSE, nullptr);
    ZeroMemory(&network_change_overlapped_, sizeof(OVERLAPPED));
    network_change_overlapped_.hEvent = network_change_event_;
    
    last_network_change_ = std::chrono::steady_clock::now();
}

NetworkChangeDetector::~NetworkChangeDetector() {
    StopMonitoring();
    
    if (network_change_event_) {
        CloseHandle(network_change_event_);
    }
    
    CleanupWinsock();
}

bool NetworkChangeDetector::StartMonitoring(const std::string& vpn_config_json) {
    if (is_monitoring_.load()) {
        std::cout << "NetworkChangeDetector: Already monitoring" << std::endl;
        return true;
    }
    
    if (!singbox_manager_) {
        std::cerr << "NetworkChangeDetector: SingboxManager is null" << std::endl;
        return false;
    }
    
    vpn_config_json_ = vpn_config_json;
    
    // Initialize Winsock
    if (!InitializeWinsock()) {
        std::cerr << "NetworkChangeDetector: Failed to initialize Winsock" << std::endl;
        return false;
    }
    
    // Register for network notifications
    if (!RegisterForNetworkNotifications()) {
        std::cerr << "NetworkChangeDetector: Failed to register for network notifications" << std::endl;
        CleanupWinsock();
        return false;
    }
    
    // Update initial network state
    UpdateNetworkInterfaces();
    UpdateNetworkState();
    
    // Start monitoring threads
    is_monitoring_.store(true);
    StartNetworkMonitorThread();
    StartHealthMonitorThread();
    
    std::cout << "NetworkChangeDetector: Monitoring started" << std::endl;
    return true;
}

void NetworkChangeDetector::StopMonitoring() {
    if (!is_monitoring_.load()) {
        return;
    }
    
    is_monitoring_.store(false);
    
    // Stop monitoring threads
    StopNetworkMonitorThread();
    StopHealthMonitorThread();
    
    // Unregister network notifications
    UnregisterNetworkNotifications();
    
    // Cleanup Winsock
    CleanupWinsock();
    
    // Reset state
    {
        std::lock_guard<std::mutex> lock(state_mutex_);
        current_network_state_ = NetworkState::Unknown;
        current_connection_health_ = ConnectionHealth::Unknown;
        current_reconnection_status_ = ReconnectionStatus::Idle;
        network_interfaces_.clear();
    }
    
    retry_attempts_.store(0);
    is_reconnecting_.store(false);
    
    std::cout << "NetworkChangeDetector: Monitoring stopped" << std::endl;
}

bool NetworkChangeDetector::IsMonitoring() const {
    return is_monitoring_.load();
}

NetworkState NetworkChangeDetector::GetNetworkState() const {
    std::lock_guard<std::mutex> lock(state_mutex_);
    return current_network_state_;
}

ConnectionHealth NetworkChangeDetector::GetConnectionHealth() const {
    std::lock_guard<std::mutex> lock(state_mutex_);
    return current_connection_health_;
}

ReconnectionStatus NetworkChangeDetector::GetReconnectionStatus() const {
    std::lock_guard<std::mutex> lock(state_mutex_);
    return current_reconnection_status_;
}

std::vector<NetworkInfo> NetworkChangeDetector::GetNetworkInterfaces() const {
    std::lock_guard<std::mutex> lock(state_mutex_);
    return network_interfaces_;
}

NetworkInfo NetworkChangeDetector::GetActiveNetworkInterface() const {
    std::lock_guard<std::mutex> lock(state_mutex_);
    return active_interface_;
}

void NetworkChangeDetector::TriggerReconnection() {
    if (!is_monitoring_.load()) {
        std::cerr << "NetworkChangeDetector: Cannot trigger reconnection - not monitoring" << std::endl;
        return;
    }
    
    if (vpn_config_json_.empty()) {
        std::cerr << "NetworkChangeDetector: Cannot trigger reconnection - no VPN configuration" << std::endl;
        return;
    }
    
    std::cout << "NetworkChangeDetector: Manual reconnection triggered" << std::endl;
    ScheduleReconnectionAttempt("Manual trigger");
}

void NetworkChangeDetector::ResetReconnectionAttempts() {
    retry_attempts_.store(0);
    
    std::lock_guard<std::mutex> lock(reconnection_mutex_);
    while (!reconnection_history_.empty()) {
        reconnection_history_.pop();
    }
    
    std::cout << "NetworkChangeDetector: Reconnection attempts reset" << std::endl;
}

void NetworkChangeDetector::SetReconnectionEnabled(bool enabled) {
    reconnection_enabled_.store(enabled);
    std::cout << "NetworkChangeDetector: Reconnection " << (enabled ? "enabled" : "disabled") << std::endl;
}

void NetworkChangeDetector::SetHealthCheckInterval(int interval_ms) {
    health_check_interval_ms_.store(interval_ms);
    std::cout << "NetworkChangeDetector: Health check interval set to " << interval_ms << "ms" << std::endl;
}

void NetworkChangeDetector::SetMaxRetryAttempts(int max_attempts) {
    max_retry_attempts_.store(max_attempts);
    std::cout << "NetworkChangeDetector: Max retry attempts set to " << max_attempts << std::endl;
}

void NetworkChangeDetector::SetNetworkStateCallback(std::function<void(NetworkState)> callback) {
    std::lock_guard<std::mutex> lock(callback_mutex_);
    network_state_callback_ = callback;
}

void NetworkChangeDetector::SetConnectionHealthCallback(std::function<void(ConnectionHealth)> callback) {
    std::lock_guard<std::mutex> lock(callback_mutex_);
    connection_health_callback_ = callback;
}

void NetworkChangeDetector::SetReconnectionCallback(std::function<void(ReconnectionStatus, int)> callback) {
    std::lock_guard<std::mutex> lock(callback_mutex_);
    reconnection_callback_ = callback;
}

std::vector<ReconnectionAttempt> NetworkChangeDetector::GetReconnectionHistory() const {
    std::lock_guard<std::mutex> lock(reconnection_mutex_);
    std::vector<ReconnectionAttempt> history;
    
    std::queue<ReconnectionAttempt> temp_queue = reconnection_history_;
    while (!temp_queue.empty()) {
        history.push_back(temp_queue.front());
        temp_queue.pop();
    }
    
    return history;
}

int NetworkChangeDetector::GetTotalReconnectionAttempts() const {
    return retry_attempts_.load();
}

std::chrono::steady_clock::time_point NetworkChangeDetector::GetLastNetworkChange() const {
    std::lock_guard<std::mutex> lock(state_mutex_);
    return last_network_change_;
}

void NetworkChangeDetector::StartNetworkMonitorThread() {
    network_monitor_running_.store(true);
    network_monitor_thread_ = std::thread(&NetworkChangeDetector::NetworkMonitorLoop, this);
}

void NetworkChangeDetector::StopNetworkMonitorThread() {
    network_monitor_running_.store(false);
    
    if (network_monitor_thread_.joinable()) {
        network_monitor_thread_.join();
    }
}

void NetworkChangeDetector::NetworkMonitorLoop() {
    std::cout << "NetworkChangeDetector: Network monitor thread started" << std::endl;
    
    while (network_monitor_running_.load()) {
        try {
            // Check for network interface changes
            DetectNetworkChanges();
            
            // Wait for network change event or timeout
            DWORD wait_result = WaitForSingleObject(network_change_event_, NETWORK_MONITOR_INTERVAL_MS);
            
            if (wait_result == WAIT_OBJECT_0) {
                std::cout << "NetworkChangeDetector: Network change event received" << std::endl;
                
                // Update network interfaces and state
                UpdateNetworkInterfaces();
                UpdateNetworkState();
                
                // Check if VPN needs reconnection
                if (reconnection_enabled_.load() && !singbox_manager_->IsRunning()) {
                    ScheduleReconnectionAttempt("Network change detected");
                }
                
                // Re-register for next notification
                RegisterForNetworkNotifications();
            }
            
        } catch (const std::exception& e) {
            std::cerr << "NetworkChangeDetector: Error in network monitor loop: " << e.what() << std::endl;
            std::this_thread::sleep_for(std::chrono::milliseconds(NETWORK_MONITOR_INTERVAL_MS));
        }
    }
    
    std::cout << "NetworkChangeDetector: Network monitor thread stopped" << std::endl;
}

void NetworkChangeDetector::StartHealthMonitorThread() {
    health_monitor_running_.store(true);
    health_monitor_thread_ = std::thread(&NetworkChangeDetector::HealthMonitorLoop, this);
}

void NetworkChangeDetector::StopHealthMonitorThread() {
    health_monitor_running_.store(false);
    
    if (health_monitor_thread_.joinable()) {
        health_monitor_thread_.join();
    }
}

void NetworkChangeDetector::HealthMonitorLoop() {
    std::cout << "NetworkChangeDetector: Health monitor thread started" << std::endl;
    
    while (health_monitor_running_.load()) {
        try {
            CheckConnectionHealth();
            
            int interval = health_check_interval_ms_.load();
            std::this_thread::sleep_for(std::chrono::milliseconds(interval));
            
        } catch (const std::exception& e) {
            std::cerr << "NetworkChangeDetector: Error in health monitor loop: " << e.what() << std::endl;
            std::this_thread::sleep_for(std::chrono::milliseconds(health_check_interval_ms_.load()));
        }
    }
    
    std::cout << "NetworkChangeDetector: Health monitor thread stopped" << std::endl;
}

void NetworkChangeDetector::CheckConnectionHealth() {
    if (!singbox_manager_->IsRunning()) {
        UpdateConnectionHealth(ConnectionHealth::Disconnected);
        return;
    }
    
    // Test internet connectivity
    bool has_internet = TestInternetConnectivity();
    bool vpn_healthy = TestVpnConnectivity();
    
    ConnectionHealth new_health;
    if (!has_internet) {
        new_health = ConnectionHealth::Disconnected;
        
        // Attempt reconnection if enabled
        if (reconnection_enabled_.load()) {
            ScheduleReconnectionAttempt("No internet connectivity");
        }
    } else if (!vpn_healthy) {
        new_health = ConnectionHealth::Poor;
    } else {
        new_health = ConnectionHealth::Good;
        // Reset retry attempts on successful health check
        retry_attempts_.store(0);
    }
    
    UpdateConnectionHealth(new_health);
}

bool NetworkChangeDetector::TestInternetConnectivity() const {
    // Test connectivity to a reliable server
    HINTERNET hInternet = InternetOpen(L"NetworkChangeDetector", INTERNET_OPEN_TYPE_DIRECT, nullptr, nullptr, 0);
    if (!hInternet) {
        return false;
    }
    
    HINTERNET hConnect = InternetOpenUrl(hInternet, L"http://www.google.com", nullptr, 0, 
                                        INTERNET_FLAG_NO_CACHE_WRITE | INTERNET_FLAG_DONT_CACHE, 0);
    
    bool connected = (hConnect != nullptr);
    
    if (hConnect) {
        InternetCloseHandle(hConnect);
    }
    InternetCloseHandle(hInternet);
    
    return connected;
}

bool NetworkChangeDetector::TestVpnConnectivity() {
    // Get VPN statistics to check if connection is active
    NetworkStats stats = singbox_manager_->GetStatistics();
    
    // If we can get statistics, assume VPN is healthy
    // More sophisticated health checks could be implemented here
    return (stats.bytes_received >= 0 && stats.bytes_sent >= 0);
}

void NetworkChangeDetector::UpdateNetworkInterfaces() {
    std::vector<NetworkInfo> interfaces = EnumerateNetworkInterfaces();
    
    std::lock_guard<std::mutex> lock(state_mutex_);
    network_interfaces_ = interfaces;
    
    // Find active interface
    DWORD active_index = GetActiveNetworkInterfaceIndex();
    for (const auto& interface : interfaces) {
        if (interface.interface_index == active_index) {
            active_interface_ = interface;
            break;
        }
    }
}

void NetworkChangeDetector::DetectNetworkChanges() {
    static std::vector<NetworkInfo> previous_interfaces;
    
    std::vector<NetworkInfo> current_interfaces = EnumerateNetworkInterfaces();
    
    // Compare with previous state
    if (HasNetworkInterfaceChanged()) {
        last_network_change_ = std::chrono::steady_clock::now();
        std::cout << "NetworkChangeDetector: Network interface change detected" << std::endl;
        
        UpdateNetworkInterfaces();
        UpdateNetworkState();
    }
    
    previous_interfaces = current_interfaces;
}

bool NetworkChangeDetector::HasNetworkInterfaceChanged() {
    // Simple implementation - could be more sophisticated
    static size_t previous_interface_count = 0;
    
    std::vector<NetworkInfo> current_interfaces = EnumerateNetworkInterfaces();
    bool changed = (current_interfaces.size() != previous_interface_count);
    
    previous_interface_count = current_interfaces.size();
    return changed;
}

std::vector<NetworkInfo> NetworkChangeDetector::EnumerateNetworkInterfaces() {
    std::vector<NetworkInfo> interfaces;
    
    ULONG buffer_size = 0;
    DWORD result = GetAdaptersInfo(nullptr, &buffer_size);
    
    if (result != ERROR_BUFFER_OVERFLOW) {
        return interfaces;
    }
    
    std::vector<BYTE> buffer(buffer_size);
    PIP_ADAPTER_INFO adapter_info = reinterpret_cast<PIP_ADAPTER_INFO>(buffer.data());
    
    result = GetAdaptersInfo(adapter_info, &buffer_size);
    if (result != NO_ERROR) {
        return interfaces;
    }
    
    PIP_ADAPTER_INFO adapter = adapter_info;
    while (adapter) {
        NetworkInfo info;
        info.adapter_name = adapter->AdapterName;
        info.adapter_description = adapter->Description;
        info.interface_index = adapter->Index;
        info.is_connected = (adapter->Type != MIB_IF_TYPE_LOOPBACK);
        info.is_ethernet = (adapter->Type == MIB_IF_TYPE_ETHERNET);
        info.is_wifi = (adapter->Type == IF_TYPE_IEEE80211);
        
        // Get IP address
        if (adapter->IpAddressList.IpAddress.String[0] != '0') {
            info.ip_address = adapter->IpAddressList.IpAddress.String;
            info.gateway = adapter->GatewayList.IpAddress.String;
        }
        
        // Assume has internet if connected and has valid IP
        info.has_internet = info.is_connected && !info.ip_address.empty() && info.ip_address != "0.0.0.0";
        
        interfaces.push_back(info);
        adapter = adapter->Next;
    }
    
    return interfaces;
}

NetworkInfo NetworkChangeDetector::GetNetworkInterfaceInfo(DWORD interface_index) {
    std::vector<NetworkInfo> interfaces = EnumerateNetworkInterfaces();
    
    for (const auto& interface : interfaces) {
        if (interface.interface_index == interface_index) {
            return interface;
        }
    }
    
    return NetworkInfo{}; // Return empty info if not found
}

void NetworkChangeDetector::AttemptReconnection(const std::string& reason) {
    if (is_reconnecting_.load()) {
        return;
    }
    
    int current_attempt = retry_attempts_.load() + 1;
    if (current_attempt > max_retry_attempts_.load()) {
        std::cout << "NetworkChangeDetector: Maximum retry attempts reached" << std::endl;
        UpdateReconnectionStatus(ReconnectionStatus::Failed);
        return;
    }
    
    is_reconnecting_.store(true);
    retry_attempts_.store(current_attempt);
    UpdateReconnectionStatus(ReconnectionStatus::Attempting);
    
    std::cout << "NetworkChangeDetector: Attempting reconnection #" << current_attempt 
              << " (reason: " << reason << ")" << std::endl;
    
    // Calculate backoff delay
    DWORD delay = CalculateBackoffDelay(current_attempt);
    std::cout << "NetworkChangeDetector: Waiting " << delay << "ms before reconnection attempt" << std::endl;
    
    std::this_thread::sleep_for(std::chrono::milliseconds(delay));
    
    // Check if we still need to reconnect
    if (!is_monitoring_.load() || singbox_manager_->IsRunning()) {
        UpdateReconnectionStatus(ReconnectionStatus::Idle);
        is_reconnecting_.store(false);
        return;
    }
    
    // Attempt to restart VPN
    bool success = singbox_manager_->Start(vpn_config_json_);
    
    RecordReconnectionAttempt(current_attempt, reason, success);
    
    if (success) {
        std::cout << "NetworkChangeDetector: Reconnection successful after " << current_attempt << " attempts" << std::endl;
        retry_attempts_.store(0);
        UpdateReconnectionStatus(ReconnectionStatus::Success);
        UpdateConnectionHealth(ConnectionHealth::Good);
        
        // Reset to idle after a short delay
        std::this_thread::sleep_for(std::chrono::milliseconds(2000));
        UpdateReconnectionStatus(ReconnectionStatus::Idle);
    } else {
        std::cout << "NetworkChangeDetector: Reconnection attempt #" << current_attempt << " failed" << std::endl;
        
        if (current_attempt >= max_retry_attempts_.load()) {
            std::cout << "NetworkChangeDetector: All reconnection attempts failed" << std::endl;
            UpdateReconnectionStatus(ReconnectionStatus::Failed);
        } else {
            // Schedule next attempt
            std::thread([this, reason]() {
                std::this_thread::sleep_for(std::chrono::milliseconds(1000));
                AttemptReconnection(reason);
            }).detach();
        }
    }
    
    is_reconnecting_.store(false);
}

void NetworkChangeDetector::ScheduleReconnectionAttempt(const std::string& reason) {
    if (!reconnection_enabled_.load()) {
        return;
    }
    
    // Schedule reconnection in a separate thread to avoid blocking
    std::thread([this, reason]() {
        AttemptReconnection(reason);
    }).detach();
}

DWORD NetworkChangeDetector::CalculateBackoffDelay(int attempt_number) {
    double delay = INITIAL_RETRY_DELAY_MS * std::pow(BACKOFF_MULTIPLIER, attempt_number - 1);
    return static_cast<DWORD>(std::min(delay, static_cast<double>(MAX_RETRY_DELAY_MS)));
}

void NetworkChangeDetector::RecordReconnectionAttempt(int attempt_number, const std::string& reason, bool success) {
    std::lock_guard<std::mutex> lock(reconnection_mutex_);
    
    ReconnectionAttempt attempt;
    attempt.attempt_number = attempt_number;
    attempt.timestamp = std::chrono::steady_clock::now();
    attempt.reason = reason;
    attempt.success = success;
    
    reconnection_history_.push(attempt);
    
    // Keep history size manageable
    while (reconnection_history_.size() > MAX_RECONNECTION_HISTORY) {
        reconnection_history_.pop();
    }
}

void NetworkChangeDetector::UpdateNetworkState() {
    NetworkState new_state = NetworkState::Unknown;
    
    if (!IsNetworkConnected()) {
        new_state = NetworkState::Disconnected;
    } else if (!HasInternetAccess()) {
        new_state = NetworkState::ConnectedNoInternet;
    } else {
        // Determine connection type based on active interface
        std::lock_guard<std::mutex> lock(state_mutex_);
        if (active_interface_.is_wifi) {
            new_state = NetworkState::ConnectedWifi;
        } else if (active_interface_.is_ethernet) {
            new_state = NetworkState::ConnectedEthernet;
        } else {
            new_state = NetworkState::ConnectedOther;
        }
    }
    
    {
        std::lock_guard<std::mutex> lock(state_mutex_);
        if (current_network_state_ != new_state) {
            current_network_state_ = new_state;
            NotifyNetworkStateChange(new_state);
        }
    }
}

void NetworkChangeDetector::UpdateConnectionHealth(ConnectionHealth new_health) {
    {
        std::lock_guard<std::mutex> lock(state_mutex_);
        if (current_connection_health_ != new_health) {
            current_connection_health_ = new_health;
            NotifyConnectionHealthChange(new_health);
        }
    }
}

void NetworkChangeDetector::UpdateReconnectionStatus(ReconnectionStatus new_status) {
    int attempt_number = retry_attempts_.load();
    
    {
        std::lock_guard<std::mutex> lock(state_mutex_);
        if (current_reconnection_status_ != new_status) {
            current_reconnection_status_ = new_status;
            NotifyReconnectionStatusChange(new_status, attempt_number);
        }
    }
}

void NetworkChangeDetector::NotifyNetworkStateChange(NetworkState new_state) {
    std::lock_guard<std::mutex> lock(callback_mutex_);
    if (network_state_callback_) {
        network_state_callback_(new_state);
    }
}

void NetworkChangeDetector::NotifyConnectionHealthChange(ConnectionHealth new_health) {
    std::lock_guard<std::mutex> lock(callback_mutex_);
    if (connection_health_callback_) {
        connection_health_callback_(new_health);
    }
}

void NetworkChangeDetector::NotifyReconnectionStatusChange(ReconnectionStatus new_status, int attempt_number) {
    std::lock_guard<std::mutex> lock(callback_mutex_);
    if (reconnection_callback_) {
        reconnection_callback_(new_status, attempt_number);
    }
}

bool NetworkChangeDetector::RegisterForNetworkNotifications() {
    // Use NotifyAddrChange for network change notifications
    DWORD result = NotifyAddrChange(&network_change_event_, &network_change_overlapped_);
    return (result == ERROR_IO_PENDING || result == NO_ERROR);
}

void NetworkChangeDetector::UnregisterNetworkNotifications() {
    // Cancel pending notifications
    if (network_change_event_) {
        SetEvent(network_change_event_);
    }
}

bool NetworkChangeDetector::InitializeWinsock() {
    if (winsock_initialized_.load()) {
        return true;
    }
    
    WSADATA wsaData;
    int result = WSAStartup(MAKEWORD(2, 2), &wsaData);
    
    if (result == 0) {
        winsock_initialized_.store(true);
        return true;
    }
    
    std::cerr << "NetworkChangeDetector: WSAStartup failed with error: " << result << std::endl;
    return false;
}

void NetworkChangeDetector::CleanupWinsock() {
    if (winsock_initialized_.load()) {
        WSACleanup();
        winsock_initialized_.store(false);
    }
}

DWORD NetworkChangeDetector::GetActiveNetworkInterfaceIndex() {
    DWORD best_interface_index = 0;
    DWORD result = GetBestInterface(inet_addr("8.8.8.8"), &best_interface_index);
    
    if (result == NO_ERROR) {
        return best_interface_index;
    }
    
    return 0;
}

std::string NetworkChangeDetector::GetInterfaceTypeString(DWORD interface_type) {
    switch (interface_type) {
        case MIB_IF_TYPE_ETHERNET: return "Ethernet";
        case IF_TYPE_IEEE80211: return "WiFi";
        case MIB_IF_TYPE_LOOPBACK: return "Loopback";
        case MIB_IF_TYPE_PPP: return "PPP";
        default: return "Other";
    }
}

bool NetworkChangeDetector::IsNetworkConnected() const {
    std::lock_guard<std::mutex> lock(state_mutex_);
    
    for (const auto& interface : network_interfaces_) {
        if (interface.is_connected && !interface.ip_address.empty() && interface.ip_address != "0.0.0.0") {
            return true;
        }
    }
    
    return false;
}

bool NetworkChangeDetector::HasInternetAccess() const {
    return TestInternetConnectivity();
}

std::string NetworkChangeDetector::NetworkStateToString(NetworkState state) const {
    switch (state) {
        case NetworkState::Unknown: return "Unknown";
        case NetworkState::Disconnected: return "Disconnected";
        case NetworkState::ConnectedNoInternet: return "Connected (No Internet)";
        case NetworkState::ConnectedWifi: return "Connected (WiFi)";
        case NetworkState::ConnectedEthernet: return "Connected (Ethernet)";
        case NetworkState::ConnectedOther: return "Connected (Other)";
        default: return "Unknown";
    }
}

std::string NetworkChangeDetector::ConnectionHealthToString(ConnectionHealth health) const {
    switch (health) {
        case ConnectionHealth::Unknown: return "Unknown";
        case ConnectionHealth::Good: return "Good";
        case ConnectionHealth::Poor: return "Poor";
        case ConnectionHealth::Disconnected: return "Disconnected";
        default: return "Unknown";
    }
}

std::string NetworkChangeDetector::ReconnectionStatusToString(ReconnectionStatus status) const {
    switch (status) {
        case ReconnectionStatus::Idle: return "Idle";
        case ReconnectionStatus::Attempting: return "Attempting";
        case ReconnectionStatus::Success: return "Success";
        case ReconnectionStatus::Failed: return "Failed";
        default: return "Unknown";
    }
}