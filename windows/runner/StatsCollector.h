#ifndef STATS_COLLECTOR_H_
#define STATS_COLLECTOR_H_

#include <windows.h>
#include <string>
#include <memory>
#include <atomic>
#include <thread>
#include <mutex>
#include <vector>
#include <functional>
#include <chrono>
#include <queue>
#include <map>
#include "SingboxManager.h"

enum class StatsCollectionError {
    None,
    CollectionFailed,
    MaxRetriesExceeded,
    SingboxNotRunning,
    ProcessingError,
    UnexpectedError
};

struct StatsCollectionErrorInfo {
    StatsCollectionError error_type;
    std::string message;
    std::chrono::steady_clock::time_point timestamp;
    int retry_count;
};

class StatsCollector {
public:
    // Constructor and destructor
    explicit StatsCollector(std::shared_ptr<SingboxManager> singbox_manager);
    ~StatsCollector();

    // Core collection methods
    bool Start(int interval_ms = 1000);
    void Stop();
    bool IsCollecting() const;

    // Configuration
    void UpdateInterval(int interval_ms);
    int GetInterval() const;

    // Statistics access
    NetworkStats GetLastStats() const;
    NetworkStats GetSmoothedStats() const;
    std::vector<NetworkStats> GetStatsHistory(int count = 5) const;

    // Error handling
    StatsCollectionError GetLastError() const;
    std::string GetLastErrorMessage() const;
    std::vector<StatsCollectionErrorInfo> GetErrorHistory(int count = 10) const;

    // Callbacks for real-time streaming
    void SetStatsCallback(std::function<void(const NetworkStats&)> callback);
    void SetErrorCallback(std::function<void(const StatsCollectionErrorInfo&)> callback);
    
    // Flutter platform channel integration
    void SetFlutterChannelCallback(std::function<void(const NetworkStats&)> flutter_callback);
    void NotifyFlutterStatsUpdate(const NetworkStats& stats);
    
    // Statistics management
    bool ResetStatistics();
    std::map<std::string, int> GetCollectionHealth() const;

    // Cleanup
    void Cleanup();

private:
    // Collection thread methods
    void CollectionThreadMain();
    void StartCollectionThread();
    void StopCollectionThread();

    // Statistics collection and processing
    bool CollectStatsWithRetry();
    NetworkStats CollectSingleStats();
    void ProcessAndEmitStats(const NetworkStats& stats);
    NetworkStats CalculateCurrentSpeeds(const NetworkStats& current, const NetworkStats& previous);

    // Statistics history management
    void UpdateStatsHistory(const NetworkStats& stats);
    NetworkStats CalculateSmoothedStats() const;

    // Error handling
    void HandleCollectionFailure(int retry_count);
    void SetError(StatsCollectionError error, const std::string& message, int retry_count = 0);
    void ClearError();

    // Utility methods
    std::string FormatStatsForLog(const NetworkStats& stats) const;
    std::string FormatBytes(long long bytes) const;
    std::string FormatSpeed(double bytes_per_second) const;

    // Member variables
    std::shared_ptr<SingboxManager> singbox_manager_;
    
    // Collection state
    std::atomic<bool> is_collecting_;
    std::atomic<int> collection_interval_ms_;
    std::thread collection_thread_;
    
    // Statistics storage
    mutable std::mutex stats_mutex_;
    NetworkStats last_stats_;
    std::queue<NetworkStats> stats_history_;
    static constexpr int MAX_HISTORY_SIZE = 10;
    
    // Error tracking
    mutable std::mutex error_mutex_;
    StatsCollectionError last_error_;
    std::string last_error_message_;
    std::queue<StatsCollectionErrorInfo> error_history_;
    static constexpr int MAX_ERROR_HISTORY_SIZE = 20;
    
    // Callbacks
    mutable std::mutex callback_mutex_;
    std::function<void(const NetworkStats&)> stats_callback_;
    std::function<void(const StatsCollectionErrorInfo&)> error_callback_;
    std::function<void(const NetworkStats&)> flutter_callback_;
    
    // Collection parameters
    static constexpr int DEFAULT_COLLECTION_INTERVAL_MS = 1000;
    static constexpr int MAX_RETRY_ATTEMPTS = 3;
    static constexpr int RETRY_DELAY_MS = 500;
    static constexpr int SMOOTHING_WINDOW_SIZE = 3;
    
    // Initialization state
    bool is_initialized_;
};

#endif // STATS_COLLECTOR_H_