#include "StatsCollector.h"
#include <iostream>
#include <sstream>
#include <iomanip>
#include <algorithm>

StatsCollector::StatsCollector(std::shared_ptr<SingboxManager> singbox_manager)
    : singbox_manager_(singbox_manager)
    , is_collecting_(false)
    , collection_interval_ms_(DEFAULT_COLLECTION_INTERVAL_MS)
    , last_error_(StatsCollectionError::None)
    , is_initialized_(false)
{
    if (!singbox_manager_) {
        SetError(StatsCollectionError::UnexpectedError, "SingboxManager is null");
        return;
    }
    
    // Initialize statistics
    last_stats_ = {};
    last_stats_.bytes_received = 0;
    last_stats_.bytes_sent = 0;
    last_stats_.connection_duration = 0;
    last_stats_.timestamp = 0;
    last_stats_.upload_speed = 0.0;
    last_stats_.download_speed = 0.0;
    last_stats_.packets_received = 0;
    last_stats_.packets_sent = 0;
    
    is_initialized_ = true;
    ClearError();
    
    std::cout << "StatsCollector initialized successfully" << std::endl;
}

StatsCollector::~StatsCollector() {
    Cleanup();
}

bool StatsCollector::Start(int interval_ms) {
    if (!is_initialized_) {
        SetError(StatsCollectionError::UnexpectedError, "StatsCollector not initialized");
        return false;
    }
    
    if (is_collecting_) {
        std::cout << "Statistics collection already running" << std::endl;
        return true;
    }
    
    if (interval_ms <= 0) {
        SetError(StatsCollectionError::UnexpectedError, "Invalid collection interval");
        return false;
    }
    
    collection_interval_ms_ = interval_ms;
    ClearError();
    
    std::cout << "Starting statistics collection with interval: " << interval_ms << "ms" << std::endl;
    
    is_collecting_ = true;
    StartCollectionThread();
    
    return true;
}

void StatsCollector::Stop() {
    if (!is_collecting_) {
        std::cout << "Statistics collection not running" << std::endl;
        return;
    }
    
    std::cout << "Stopping statistics collection" << std::endl;
    
    is_collecting_ = false;
    StopCollectionThread();
    
    // Clear cached data
    {
        std::lock_guard<std::mutex> lock(stats_mutex_);
        while (!stats_history_.empty()) {
            stats_history_.pop();
        }
    }
    
    std::cout << "Statistics collection stopped" << std::endl;
}

bool StatsCollector::IsCollecting() const {
    return is_collecting_;
}

void StatsCollector::UpdateInterval(int interval_ms) {
    if (interval_ms <= 0) {
        std::cerr << "Invalid interval: " << interval_ms << ", ignoring" << std::endl;
        return;
    }
    
    collection_interval_ms_ = interval_ms;
    std::cout << "Updated collection interval to: " << interval_ms << "ms" << std::endl;
}

int StatsCollector::GetInterval() const {
    return collection_interval_ms_;
}

NetworkStats StatsCollector::GetLastStats() const {
    std::lock_guard<std::mutex> lock(stats_mutex_);
    return last_stats_;
}

NetworkStats StatsCollector::GetSmoothedStats() const {
    std::lock_guard<std::mutex> lock(stats_mutex_);
    return CalculateSmoothedStats();
}

std::vector<NetworkStats> StatsCollector::GetStatsHistory(int count) const {
    std::lock_guard<std::mutex> lock(stats_mutex_);
    
    std::vector<NetworkStats> history;
    std::queue<NetworkStats> temp_queue = stats_history_;
    
    // Convert queue to vector (most recent first)
    std::vector<NetworkStats> all_stats;
    while (!temp_queue.empty()) {
        all_stats.push_back(temp_queue.front());
        temp_queue.pop();
    }
    
    // Return the most recent 'count' items
    int start_index = std::max(0, static_cast<int>(all_stats.size()) - count);
    for (int i = start_index; i < static_cast<int>(all_stats.size()); ++i) {
        history.push_back(all_stats[i]);
    }
    
    return history;
}

StatsCollectionError StatsCollector::GetLastError() const {
    std::lock_guard<std::mutex> lock(error_mutex_);
    return last_error_;
}

std::string StatsCollector::GetLastErrorMessage() const {
    std::lock_guard<std::mutex> lock(error_mutex_);
    return last_error_message_;
}

std::vector<StatsCollectionErrorInfo> StatsCollector::GetErrorHistory(int count) const {
    std::lock_guard<std::mutex> lock(error_mutex_);
    
    std::vector<StatsCollectionErrorInfo> history;
    std::queue<StatsCollectionErrorInfo> temp_queue = error_history_;
    
    // Convert queue to vector (most recent first)
    std::vector<StatsCollectionErrorInfo> all_errors;
    while (!temp_queue.empty()) {
        all_errors.push_back(temp_queue.front());
        temp_queue.pop();
    }
    
    // Return the most recent 'count' items
    int start_index = std::max(0, static_cast<int>(all_errors.size()) - count);
    for (int i = start_index; i < static_cast<int>(all_errors.size()); ++i) {
        history.push_back(all_errors[i]);
    }
    
    return history;
}

void StatsCollector::SetStatsCallback(std::function<void(const NetworkStats&)> callback) {
    std::lock_guard<std::mutex> lock(callback_mutex_);
    stats_callback_ = callback;
}

void StatsCollector::SetErrorCallback(std::function<void(const StatsCollectionErrorInfo&)> callback) {
    std::lock_guard<std::mutex> lock(callback_mutex_);
    error_callback_ = callback;
}

void StatsCollector::SetFlutterChannelCallback(std::function<void(const NetworkStats&)> flutter_callback) {
    std::lock_guard<std::mutex> lock(callback_mutex_);
    flutter_callback_ = flutter_callback;
}

void StatsCollector::NotifyFlutterStatsUpdate(const NetworkStats& stats) {
    std::lock_guard<std::mutex> lock(callback_mutex_);
    if (flutter_callback_) {
        try {
            flutter_callback_(stats);
        } catch (const std::exception& e) {
            std::cerr << "Error notifying Flutter about stats update: " << e.what() << std::endl;
        }
    }
}

bool StatsCollector::ResetStatistics() {
    if (!is_initialized_) {
        return false;
    }
    
    try {
        // Clear local statistics cache
        {
            std::lock_guard<std::mutex> lock(stats_mutex_);
            last_stats_ = {};
            last_stats_.bytes_received = 0;
            last_stats_.bytes_sent = 0;
            last_stats_.connection_duration = 0;
            last_stats_.timestamp = 0;
            last_stats_.upload_speed = 0.0;
            last_stats_.download_speed = 0.0;
            last_stats_.packets_received = 0;
            last_stats_.packets_sent = 0;
            
            // Clear history
            while (!stats_history_.empty()) {
                stats_history_.pop();
            }
        }
        
        // Clear errors
        ClearError();
        
        std::cout << "Statistics reset successfully" << std::endl;
        return true;
    } catch (const std::exception& e) {
        std::cerr << "Exception resetting statistics: " << e.what() << std::endl;
        return false;
    }
}

std::map<std::string, int> StatsCollector::GetCollectionHealth() const {
    std::map<std::string, int> health;
    
    health["isCollecting"] = is_collecting_ ? 1 : 0;
    health["collectionInterval"] = collection_interval_ms_;
    
    {
        std::lock_guard<std::mutex> lock(stats_mutex_);
        health["statsHistorySize"] = static_cast<int>(stats_history_.size());
        health["hasLastStats"] = (last_stats_.timestamp > 0) ? 1 : 0;
    }
    
    health["singboxRunning"] = (singbox_manager_ && singbox_manager_->IsRunning()) ? 1 : 0;
    health["isInitialized"] = is_initialized_ ? 1 : 0;
    
    {
        std::lock_guard<std::mutex> lock(error_mutex_);
        health["lastErrorCode"] = static_cast<int>(last_error_);
        health["errorHistorySize"] = static_cast<int>(error_history_.size());
    }
    
    return health;
}

void StatsCollector::Cleanup() {
    Stop();
    
    // Clear callbacks
    {
        std::lock_guard<std::mutex> lock(callback_mutex_);
        stats_callback_ = nullptr;
        error_callback_ = nullptr;
        flutter_callback_ = nullptr;
    }
    
    std::cout << "StatsCollector cleanup completed" << std::endl;
}

void StatsCollector::CollectionThreadMain() {
    std::cout << "Statistics collection thread started" << std::endl;
    
    int retry_count = 0;
    
    while (is_collecting_) {
        try {
            bool success = CollectStatsWithRetry();
            if (success) {
                retry_count = 0; // Reset retry count on success
            } else {
                HandleCollectionFailure(retry_count++);
            }
            
            // Sleep for the specified interval
            std::this_thread::sleep_for(std::chrono::milliseconds(collection_interval_ms_));
            
        } catch (const std::exception& e) {
            std::cerr << "Error in collection thread: " << e.what() << std::endl;
            HandleCollectionFailure(retry_count++);
            std::this_thread::sleep_for(std::chrono::milliseconds(RETRY_DELAY_MS));
        }
    }
    
    std::cout << "Statistics collection thread stopped" << std::endl;
}

void StatsCollector::StartCollectionThread() {
    collection_thread_ = std::thread(&StatsCollector::CollectionThreadMain, this);
}

void StatsCollector::StopCollectionThread() {
    if (collection_thread_.joinable()) {
        collection_thread_.join();
    }
}

bool StatsCollector::CollectStatsWithRetry() {
    for (int attempt = 0; attempt < MAX_RETRY_ATTEMPTS; ++attempt) {
        try {
            if (!singbox_manager_->IsRunning()) {
                std::cout << "Sing-box not running, skipping stats collection" << std::endl;
                return false;
            }
            
            NetworkStats stats = CollectSingleStats();
            ProcessAndEmitStats(stats);
            
            if (attempt > 0) {
                std::cout << "Successfully collected statistics on attempt " << (attempt + 1) << std::endl;
            }
            
            return true;
            
        } catch (const std::exception& e) {
            std::cerr << "Failed to collect statistics on attempt " << (attempt + 1) << ": " << e.what() << std::endl;
            if (attempt < MAX_RETRY_ATTEMPTS - 1) {
                std::this_thread::sleep_for(std::chrono::milliseconds(RETRY_DELAY_MS * (attempt + 1)));
            }
        }
    }
    
    return false;
}

NetworkStats StatsCollector::CollectSingleStats() {
    if (!singbox_manager_) {
        throw std::runtime_error("SingboxManager is null");
    }
    
    NetworkStats stats = singbox_manager_->GetStatistics();
    
    // Update timestamp to current time
    stats.timestamp = std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    
    return stats;
}

void StatsCollector::ProcessAndEmitStats(const NetworkStats& stats) {
    try {
        NetworkStats processed_stats = stats;
        
        // Calculate current speeds if we have previous stats
        {
            std::lock_guard<std::mutex> lock(stats_mutex_);
            if (last_stats_.timestamp > 0) {
                processed_stats = CalculateCurrentSpeeds(stats, last_stats_);
            }
        }
        
        // Update history and cache
        UpdateStatsHistory(processed_stats);
        
        {
            std::lock_guard<std::mutex> lock(stats_mutex_);
            last_stats_ = processed_stats;
        }
        
        // Emit to callback
        {
            std::lock_guard<std::mutex> lock(callback_mutex_);
            if (stats_callback_) {
                stats_callback_(processed_stats);
            }
        }
        
        // Notify Flutter about statistics update
        NotifyFlutterStatsUpdate(processed_stats);
        
        // Log statistics (verbose)
        std::cout << "Emitted statistics: " << FormatStatsForLog(processed_stats) << std::endl;
        
    } catch (const std::exception& e) {
        std::cerr << "Error processing statistics: " << e.what() << std::endl;
        SetError(StatsCollectionError::ProcessingError, "Processing failed: " + std::string(e.what()));
    }
}

NetworkStats StatsCollector::CalculateCurrentSpeeds(const NetworkStats& current, const NetworkStats& previous) {
    NetworkStats result = current;
    
    long long time_diff = current.timestamp - previous.timestamp;
    if (time_diff <= 0) {
        return result;
    }
    
    long long bytes_diff_received = std::max(0LL, current.bytes_received - previous.bytes_received);
    long long bytes_diff_sent = std::max(0LL, current.bytes_sent - previous.bytes_sent);
    
    result.download_speed = static_cast<double>(bytes_diff_received) / time_diff;
    result.upload_speed = static_cast<double>(bytes_diff_sent) / time_diff;
    
    return result;
}

void StatsCollector::UpdateStatsHistory(const NetworkStats& stats) {
    std::lock_guard<std::mutex> lock(stats_mutex_);
    
    stats_history_.push(stats);
    if (stats_history_.size() > MAX_HISTORY_SIZE) {
        stats_history_.pop();
    }
}

NetworkStats StatsCollector::CalculateSmoothedStats() const {
    if (stats_history_.size() < 2) {
        return last_stats_;
    }
    
    try {
        // Get recent stats for smoothing
        std::vector<NetworkStats> recent_stats;
        std::queue<NetworkStats> temp_queue = stats_history_;
        
        while (!temp_queue.empty()) {
            recent_stats.push_back(temp_queue.front());
            temp_queue.pop();
        }
        
        // Take the most recent SMOOTHING_WINDOW_SIZE stats
        int start_index = std::max(0, static_cast<int>(recent_stats.size()) - SMOOTHING_WINDOW_SIZE);
        
        double avg_download_speed = 0.0;
        double avg_upload_speed = 0.0;
        int count = 0;
        
        for (int i = start_index; i < static_cast<int>(recent_stats.size()); ++i) {
            avg_download_speed += recent_stats[i].download_speed;
            avg_upload_speed += recent_stats[i].upload_speed;
            count++;
        }
        
        if (count > 0) {
            avg_download_speed /= count;
            avg_upload_speed /= count;
        }
        
        NetworkStats smoothed = last_stats_;
        smoothed.download_speed = avg_download_speed;
        smoothed.upload_speed = avg_upload_speed;
        
        return smoothed;
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to calculate smoothed stats: " << e.what() << std::endl;
        return last_stats_;
    }
}

void StatsCollector::HandleCollectionFailure(int retry_count) {
    if (retry_count >= MAX_RETRY_ATTEMPTS) {
        std::cerr << "Max retry attempts reached, emitting error" << std::endl;
        SetError(StatsCollectionError::MaxRetriesExceeded, "Max retry attempts exceeded", retry_count);
        // Wait longer before next attempt
        std::this_thread::sleep_for(std::chrono::milliseconds(collection_interval_ms_));
    } else if (!singbox_manager_->IsRunning()) {
        std::cout << "Sing-box not running, pausing collection" << std::endl;
        SetError(StatsCollectionError::SingboxNotRunning, "Sing-box is not running", retry_count);
        // Wait longer when not running
        std::this_thread::sleep_for(std::chrono::milliseconds(collection_interval_ms_ * 2));
    } else {
        std::cerr << "Collection failed, retry " << retry_count << std::endl;
        SetError(StatsCollectionError::CollectionFailed, "Collection failed", retry_count);
    }
}

void StatsCollector::SetError(StatsCollectionError error, const std::string& message, int retry_count) {
    std::lock_guard<std::mutex> lock(error_mutex_);
    
    last_error_ = error;
    last_error_message_ = message;
    
    // Add to error history
    StatsCollectionErrorInfo error_info;
    error_info.error_type = error;
    error_info.message = message;
    error_info.timestamp = std::chrono::steady_clock::now();
    error_info.retry_count = retry_count;
    
    error_history_.push(error_info);
    if (error_history_.size() > MAX_ERROR_HISTORY_SIZE) {
        error_history_.pop();
    }
    
    // Emit to callback
    {
        std::lock_guard<std::mutex> callback_lock(callback_mutex_);
        if (error_callback_) {
            error_callback_(error_info);
        }
    }
}

void StatsCollector::ClearError() {
    std::lock_guard<std::mutex> lock(error_mutex_);
    last_error_ = StatsCollectionError::None;
    last_error_message_.clear();
}

std::string StatsCollector::FormatStatsForLog(const NetworkStats& stats) const {
    std::ostringstream oss;
    oss << "NetworkStats(↓" << FormatBytes(stats.bytes_received) 
        << " ↑" << FormatBytes(stats.bytes_sent)
        << " ↓" << FormatSpeed(stats.download_speed)
        << " ↑" << FormatSpeed(stats.upload_speed) << ")";
    return oss.str();
}

std::string StatsCollector::FormatBytes(long long bytes) const {
    if (bytes < 1024) {
        return std::to_string(bytes) + "B";
    } else if (bytes < 1024 * 1024) {
        return std::to_string(bytes / 1024) + "KB";
    } else {
        return std::to_string(bytes / (1024 * 1024)) + "MB";
    }
}

std::string StatsCollector::FormatSpeed(double bytes_per_second) const {
    if (bytes_per_second < 1024) {
        return std::to_string(static_cast<int>(bytes_per_second)) + "B/s";
    } else if (bytes_per_second < 1024 * 1024) {
        return std::to_string(static_cast<int>(bytes_per_second / 1024)) + "KB/s";
    } else {
        return std::to_string(static_cast<int>(bytes_per_second / (1024 * 1024))) + "MB/s";
    }
}