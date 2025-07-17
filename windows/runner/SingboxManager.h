#ifndef SINGBOX_MANAGER_H_
#define SINGBOX_MANAGER_H_

#include <windows.h>
#include <string>
#include <memory>
#include <atomic>
#include <thread>
#include <mutex>
#include <vector>
#include <functional>
#include <map>
#include <chrono>

struct NetworkStats {
    long long bytes_received;
    long long bytes_sent;
    long long connection_duration;
    long long timestamp;
    double upload_speed;
    double download_speed;
    int packets_received;
    int packets_sent;
};

enum class SingboxError {
    None,
    InitializationFailed,
    ConfigurationInvalid,
    ProcessStartFailed,
    ProcessCrashed,
    NetworkError,
    PermissionDenied,
    ResourceExhausted,
    UnknownError
};

struct SingboxStatus {
    bool is_running;
    SingboxError last_error;
    std::string error_message;
    std::chrono::steady_clock::time_point start_time;
};

class SingboxManager {
public:
    SingboxManager();
    ~SingboxManager();

    // Core lifecycle methods
    bool Initialize();
    bool Start(const std::string& config_json);
    bool Stop();
    void Cleanup();

    // Status and statistics
    bool IsRunning() const;
    SingboxStatus GetStatus() const;
    NetworkStats GetStatistics() const;

    // Configuration management
    bool ValidateConfiguration(const std::string& config_json) const;
    std::vector<std::string> GetSupportedProtocols() const;

    // Error handling
    SingboxError GetLastError() const;
    std::string GetLastErrorMessage() const;

    // Process monitoring
    void SetProcessMonitorCallback(std::function<void(SingboxError, const std::string&)> callback);

    // Enhanced logging and debugging methods
    static void SetDebugMode(bool enabled);
    static void SetVerboseLogging(bool enabled);
    static bool IsDebugMode();
    static bool IsVerboseLogging();
    
    void LogNativeOutput(const std::string& output, const std::string& source = "singbox-native");
    std::vector<std::string> GetErrorHistory() const;
    std::map<std::string, long long> GetOperationTimings() const;
    void ClearDiagnosticData();
    std::map<std::string, std::string> GenerateDiagnosticReport() const;
    
    // Export diagnostic logs to JSON format
    std::string ExportDiagnosticLogs() const;
    
    // Advanced features from design document
    bool SetLogLevel(int level);
    std::vector<std::string> GetLogs() const;
    bool UpdateConfiguration(const std::string& config_json);
    std::map<std::string, int> GetMemoryUsage() const;
    bool OptimizePerformance();
    bool HandleNetworkChange(const std::string& network_info_json);
    std::map<std::string, std::string> GetConnectionInfo() const;
    std::string GetVersion() const;

private:
    // Process management
    bool StartSingboxProcess(const std::string& config_json);
    bool StopSingboxProcess();
    bool IsSingboxProcessRunning() const;
    void MonitorProcess();
    void StartProcessMonitorThread();
    void StopProcessMonitorThread();

    // Configuration file management
    std::string CreateConfigFile(const std::string& config_json);
    void CleanupConfigFile();
    bool ValidateConfigurationStructure(const std::string& config_json) const;
    bool ValidateProtocolSupport(const std::string& config_json) const;

    // Statistics collection
    void UpdateStatistics();
    void StartStatisticsThread();
    void StopStatisticsThread();
    bool ParseSingboxStats(const std::string& stats_output);

    // Error handling
    void SetError(SingboxError error, const std::string& message);
    void ClearError();

    // Member variables
    HANDLE process_handle_;
    DWORD process_id_;
    std::string config_file_path_;
    std::string singbox_executable_path_;
    
    // Status and error tracking
    mutable std::mutex status_mutex_;
    SingboxStatus current_status_;
    SingboxError last_error_;
    std::string last_error_message_;
    
    // Statistics
    mutable std::mutex stats_mutex_;
    NetworkStats current_stats_;
    NetworkStats previous_stats_;
    std::chrono::steady_clock::time_point start_time_;
    std::chrono::steady_clock::time_point last_stats_update_;
    
    // Threading
    std::atomic<bool> is_running_;
    std::atomic<bool> stats_thread_running_;
    std::atomic<bool> monitor_thread_running_;
    std::thread stats_thread_;
    std::thread monitor_thread_;
    
    // Callbacks
    std::function<void(SingboxError, const std::string&)> process_monitor_callback_;
    mutable std::mutex callback_mutex_;
    
    // Initialization state
    bool is_initialized_;
    
    // Enhanced logging and debugging infrastructure
    static bool debug_mode_;
    static bool verbose_logging_;
    mutable std::mutex logging_mutex_;
    std::vector<std::string> error_history_;
    std::map<std::string, long long> operation_timings_;
    static constexpr size_t MAX_ERROR_HISTORY = 50;
    
    // Private logging methods
    void LogOperationTiming(const std::string& operation, long long start_time, bool success = true);
    void LogDetailedError(const std::string& operation, const std::string& error, 
                         const std::string& native_error = "", const std::string& config_info = "");
    void LogProcessLifecycle(const std::string& event, const std::string& message, 
                           const std::map<std::string, std::string>& process_info = {});
    void LogConfigurationValidation(const std::string& config_json, bool is_valid, 
                                  const std::vector<std::string>& errors = {});
    
    // Constants
    static constexpr const char* SINGBOX_EXECUTABLE_NAME = "sing-box.exe";
    static constexpr const char* CONFIG_FILE_PREFIX = "singbox_config_";
    static constexpr int STATS_UPDATE_INTERVAL_MS = 1000;
    static constexpr int PROCESS_MONITOR_INTERVAL_MS = 2000;
    static constexpr int PROCESS_START_TIMEOUT_MS = 10000;
};

#endif // SINGBOX_MANAGER_H_