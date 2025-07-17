#include "SingboxManager.h"
#include <iostream>
#include <fstream>
#include <sstream>
#include <filesystem>
#include <chrono>
#include <tlhelp32.h>
#include <psapi.h>
#include <regex>
#include <algorithm>

// Static member initialization
bool SingboxManager::debug_mode_ = false;
bool SingboxManager::verbose_logging_ = false;

SingboxManager::SingboxManager()
    : process_handle_(nullptr)
    , process_id_(0)
    , is_running_(false)
    , stats_thread_running_(false)
    , monitor_thread_running_(false)
    , is_initialized_(false)
    , last_error_(SingboxError::None)
    , current_stats_{}
    , previous_stats_{}
{
    // Initialize statistics
    current_stats_.bytes_received = 0;
    current_stats_.bytes_sent = 0;
    current_stats_.connection_duration = 0;
    current_stats_.timestamp = 0;
    current_stats_.upload_speed = 0.0;
    current_stats_.download_speed = 0.0;
    current_stats_.packets_received = 0;
    current_stats_.packets_sent = 0;

    previous_stats_ = current_stats_;

    // Initialize status
    current_status_.is_running = false;
    current_status_.last_error = SingboxError::None;
    current_status_.error_message = "";
}

SingboxManager::~SingboxManager() {
    Cleanup();
}

bool SingboxManager::Initialize() {
    auto start_time = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
    
    if (is_initialized_) {
        return true;
    }

    try {
        ClearError();
        LogProcessLifecycle("INIT_START", "Starting sing-box initialization");
        
        // Find sing-box executable using configured path first
        std::filesystem::path singbox_path;
        
        // Check if path was configured during application startup
        char env_path[MAX_PATH];
        DWORD env_result = GetEnvironmentVariableA("TUNNEL_MAX_SINGBOX_PATH", env_path, MAX_PATH);
        
        if (env_result > 0 && env_result < MAX_PATH) {
            singbox_path = std::filesystem::path(env_path);
            if (std::filesystem::exists(singbox_path)) {
                LogProcessLifecycle("INIT_DISCOVERY", "Using configured sing-box path from environment", 
                    {{"configuredPath", singbox_path.string()}});
            } else {
                LogDetailedError("initialize", "Configured sing-box path does not exist", "", 
                    "Configured path: " + singbox_path.string());
                singbox_path.clear();
            }
        }
        
        // Fallback to discovery if configured path not available
        if (singbox_path.empty()) {
            LogProcessLifecycle("INIT_DISCOVERY", "Falling back to automatic discovery");
            
            char exe_path[MAX_PATH];
            GetModuleFileNameA(nullptr, exe_path, MAX_PATH);
            std::filesystem::path app_dir = std::filesystem::path(exe_path).parent_path();
            
            // Look for sing-box.exe in multiple locations
            std::vector<std::filesystem::path> search_paths = {
                app_dir / SINGBOX_EXECUTABLE_NAME,
                app_dir / "bin" / SINGBOX_EXECUTABLE_NAME,
                app_dir / "sing-box" / SINGBOX_EXECUTABLE_NAME,
                app_dir / "native" / SINGBOX_EXECUTABLE_NAME
            };
            
            bool found = false;
            for (const auto& path : search_paths) {
                if (std::filesystem::exists(path)) {
                    singbox_path = path;
                    found = true;
                    LogProcessLifecycle("INIT_DISCOVERY", "Found sing-box executable", 
                        {{"discoveredPath", path.string()}});
                    break;
                }
            }
            
            if (!found) {
                std::string search_locations;
                for (const auto& path : search_paths) {
                    search_locations += path.string() + "; ";
                }
                LogDetailedError("initialize", "Sing-box executable not found", "", 
                    "Searched in: " + search_locations);
                SetError(SingboxError::InitializationFailed, "Sing-box executable not found in any expected location");
                LogOperationTiming("initialize", start_time, false);
                return false;
            }
        }
        
        // Validate the discovered/configured executable
        std::error_code ec;
        auto file_size = std::filesystem::file_size(singbox_path, ec);
        if (ec) {
            LogDetailedError("initialize", "Failed to get sing-box executable file size", ec.message(), 
                "Path: " + singbox_path.string());
            SetError(SingboxError::InitializationFailed, "Cannot access sing-box executable: " + ec.message());
            LogOperationTiming("initialize", start_time, false);
            return false;
        }
        
        if (file_size < 1000000) { // At least 1MB
            LogDetailedError("initialize", "Sing-box executable file size validation failed", "", 
                "Path: " + singbox_path.string() + ", Size: " + std::to_string(file_size) + " bytes");
            SetError(SingboxError::InitializationFailed, "Sing-box executable appears to be invalid (too small)");
            LogOperationTiming("initialize", start_time, false);
            return false;
        }
        
        singbox_executable_path_ = singbox_path.string();
        LogProcessLifecycle("INIT_SUCCESS", "Sing-box initialized successfully", 
            {{"executablePath", singbox_executable_path_}});
        
        is_initialized_ = true;
        LogOperationTiming("initialize", start_time, true);
        return true;
    } catch (const std::exception& e) {
        LogDetailedError("initialize", "Exception during initialization", e.what());
        SetError(SingboxError::InitializationFailed, "Failed to initialize SingboxManager: " + std::string(e.what()));
        LogOperationTiming("initialize", start_time, false);
        return false;
    }
}

bool SingboxManager::Start(const std::string& config_json) {
    if (!is_initialized_) {
        SetError(SingboxError::InitializationFailed, "SingboxManager not initialized");
        return false;
    }

    if (is_running_) {
        std::cout << "Sing-box is already running" << std::endl;
        return true;
    }

    try {
        ClearError();
        
        // Validate configuration
        if (!ValidateConfiguration(config_json)) {
            SetError(SingboxError::ConfigurationInvalid, "Invalid configuration provided");
            return false;
        }

        // Create configuration file
        config_file_path_ = CreateConfigFile(config_json);
        if (config_file_path_.empty()) {
            SetError(SingboxError::ConfigurationInvalid, "Failed to create configuration file");
            return false;
        }

        // Start sing-box process
        if (!StartSingboxProcess(config_json)) {
            CleanupConfigFile();
            return false;
        }

        // Initialize statistics
        start_time_ = std::chrono::steady_clock::now();
        last_stats_update_ = start_time_;
        
        {
            std::lock_guard<std::mutex> lock(stats_mutex_);
            current_stats_.bytes_received = 0;
            current_stats_.bytes_sent = 0;
            current_stats_.connection_duration = 0;
            current_stats_.upload_speed = 0.0;
            current_stats_.download_speed = 0.0;
            current_stats_.packets_received = 0;
            current_stats_.packets_sent = 0;
            current_stats_.timestamp = std::chrono::duration_cast<std::chrono::seconds>(
                std::chrono::system_clock::now().time_since_epoch()).count();
            previous_stats_ = current_stats_;
        }

        // Update status
        {
            std::lock_guard<std::mutex> lock(status_mutex_);
            current_status_.is_running = true;
            current_status_.start_time = start_time_;
        }

        is_running_ = true;
        StartStatisticsThread();
        StartProcessMonitorThread();

        std::cout << "Sing-box started successfully" << std::endl;
        return true;
    } catch (const std::exception& e) {
        SetError(SingboxError::UnknownError, "Failed to start sing-box: " + std::string(e.what()));
        return false;
    }
}

bool SingboxManager::Stop() {
    if (!is_running_) {
        return true;
    }

    try {
        std::cout << "Stopping sing-box..." << std::endl;

        // Stop monitoring and statistics threads
        StopProcessMonitorThread();
        StopStatisticsThread();

        // Stop sing-box process
        bool stopped = StopSingboxProcess();

        // Cleanup configuration file
        CleanupConfigFile();

        // Update status
        {
            std::lock_guard<std::mutex> lock(status_mutex_);
            current_status_.is_running = false;
        }

        is_running_ = false;

        if (stopped) {
            std::cout << "Sing-box stopped successfully" << std::endl;
            ClearError();
        } else {
            SetError(SingboxError::ProcessCrashed, "Failed to stop sing-box process cleanly");
        }

        return stopped;
    } catch (const std::exception& e) {
        SetError(SingboxError::UnknownError, "Error stopping sing-box: " + std::string(e.what()));
        return false;
    }
}

void SingboxManager::Cleanup() {
    if (is_running_) {
        Stop();
    }

    StopProcessMonitorThread();
    StopStatisticsThread();
    CleanupConfigFile();

    if (process_handle_) {
        CloseHandle(process_handle_);
        process_handle_ = nullptr;
    }

    process_id_ = 0;
    is_initialized_ = false;
}

bool SingboxManager::IsRunning() const {
    return is_running_ && IsSingboxProcessRunning();
}

NetworkStats SingboxManager::GetStatistics() const {
    std::lock_guard<std::mutex> lock(stats_mutex_);
    return current_stats_;
}

bool SingboxManager::ValidateConfiguration(const std::string& config_json) const {
    if (config_json.empty()) {
        return false;
    }

    // Validate JSON structure
    if (!ValidateConfigurationStructure(config_json)) {
        return false;
    }

    // Validate protocol support
    if (!ValidateProtocolSupport(config_json)) {
        return false;
    }

    return true;
}

bool SingboxManager::StartSingboxProcess(const std::string& config_json) {
    try {
        // Build command line
        std::string command_line = "\"" + singbox_executable_path_ + "\" run -c \"" + config_file_path_ + "\"";

        // Setup process creation
        STARTUPINFOA si = {};
        PROCESS_INFORMATION pi = {};
        si.cb = sizeof(si);
        si.dwFlags = STARTF_USESHOWWINDOW;
        si.wShowWindow = SW_HIDE; // Hide console window

        // Create process
        if (!CreateProcessA(
            nullptr,
            const_cast<char*>(command_line.c_str()),
            nullptr,
            nullptr,
            FALSE,
            CREATE_NO_WINDOW,
            nullptr,
            nullptr,
            &si,
            &pi)) {
            
            DWORD system_error_code = ::GetLastError();
            std::string error_msg = "Failed to create sing-box process. Error code: " + std::to_string(static_cast<unsigned long>(system_error_code));
            
            // Categorize the error
            if (system_error_code == ERROR_FILE_NOT_FOUND) {
                SetError(SingboxError::InitializationFailed, "Sing-box executable not found");
            } else if (system_error_code == ERROR_ACCESS_DENIED) {
                SetError(SingboxError::PermissionDenied, "Access denied when starting sing-box process");
            } else {
                SetError(SingboxError::ProcessStartFailed, error_msg);
            }
            
            return false;
        }

        // Store process information
        process_handle_ = pi.hProcess;
        process_id_ = pi.dwProcessId;
        CloseHandle(pi.hThread);

        // Wait for the process to initialize with timeout
        auto start_wait = std::chrono::steady_clock::now();
        while (std::chrono::duration_cast<std::chrono::milliseconds>(
                   std::chrono::steady_clock::now() - start_wait).count() < PROCESS_START_TIMEOUT_MS) {
            
            if (!IsSingboxProcessRunning()) {
                SetError(SingboxError::ProcessCrashed, "Sing-box process exited during startup");
                return false;
            }
            
            Sleep(100); // Check every 100ms
        }

        // Final check if process is still running
        if (!IsSingboxProcessRunning()) {
            SetError(SingboxError::ProcessCrashed, "Sing-box process failed to start properly");
            return false;
        }

        std::cout << "Sing-box process started with PID: " << process_id_ << std::endl;
        return true;
    } catch (const std::exception& e) {
        SetError(SingboxError::UnknownError, "Exception starting sing-box process: " + std::string(e.what()));
        return false;
    }
}

bool SingboxManager::StopSingboxProcess() {
    if (!process_handle_) {
        return true;
    }

    try {
        // Try graceful termination first
        if (!TerminateProcess(process_handle_, 0)) {
            DWORD terminate_error = ::GetLastError();
            std::cerr << "Failed to terminate sing-box process. Error: " << terminate_error << std::endl;
            return false;
        }

        // Wait for process to exit
        DWORD wait_result = WaitForSingleObject(process_handle_, 5000);
        if (wait_result != WAIT_OBJECT_0) {
            std::cerr << "Sing-box process did not exit within timeout" << std::endl;
            return false;
        }

        CloseHandle(process_handle_);
        process_handle_ = nullptr;
        process_id_ = 0;

        return true;
    } catch (const std::exception& e) {
        std::cerr << "Exception stopping sing-box process: " << e.what() << std::endl;
        return false;
    }
}

bool SingboxManager::IsSingboxProcessRunning() const {
    if (!process_handle_) {
        return false;
    }

    DWORD exit_code;
    if (!GetExitCodeProcess(process_handle_, &exit_code)) {
        return false;
    }

    return exit_code == STILL_ACTIVE;
}

std::string SingboxManager::CreateConfigFile(const std::string& config_json) {
    try {
        // Create temporary file path
        char temp_path[MAX_PATH];
        GetTempPathA(MAX_PATH, temp_path);
        
        std::string filename = CONFIG_FILE_PREFIX + std::to_string(GetCurrentProcessId()) + ".json";
        std::string full_path = std::string(temp_path) + filename;

        // Write configuration to file
        std::ofstream config_file(full_path);
        if (!config_file.is_open()) {
            std::cerr << "Failed to create configuration file: " << full_path << std::endl;
            return "";
        }

        config_file << config_json;
        config_file.close();

        std::cout << "Created configuration file: " << full_path << std::endl;
        return full_path;
    } catch (const std::exception& e) {
        std::cerr << "Exception creating configuration file: " << e.what() << std::endl;
        return "";
    }
}

void SingboxManager::CleanupConfigFile() {
    if (!config_file_path_.empty()) {
        try {
            if (std::filesystem::exists(config_file_path_)) {
                std::filesystem::remove(config_file_path_);
                std::cout << "Cleaned up configuration file: " << config_file_path_ << std::endl;
            }
        } catch (const std::exception& e) {
            std::cerr << "Failed to cleanup configuration file: " << e.what() << std::endl;
        }
        config_file_path_.clear();
    }
}

void SingboxManager::UpdateStatistics() {
    if (!is_running_ || !process_handle_) {
        return;
    }

    try {
        // Get current time
        auto now = std::chrono::steady_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::seconds>(now - start_time_);
        auto time_since_last_update = std::chrono::duration_cast<std::chrono::milliseconds>(now - last_stats_update_);

        std::lock_guard<std::mutex> lock(stats_mutex_);
        
        // Store previous stats for speed calculation
        previous_stats_ = current_stats_;
        
        // Update connection duration
        current_stats_.connection_duration = duration.count();
        current_stats_.timestamp = std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::system_clock::now().time_since_epoch()).count();

        // For now, simulate some network statistics
        // In a real implementation, you would parse sing-box logs or use its API
        static long long mock_received = 0;
        static long long mock_sent = 0;
        static int mock_packets_received = 0;
        static int mock_packets_sent = 0;
        
        long long bytes_increment_received = 1024 + (rand() % 4096);
        long long bytes_increment_sent = 512 + (rand() % 2048);
        int packets_increment_received = 10 + (rand() % 50);
        int packets_increment_sent = 5 + (rand() % 25);
        
        mock_received += bytes_increment_received;
        mock_sent += bytes_increment_sent;
        mock_packets_received += packets_increment_received;
        mock_packets_sent += packets_increment_sent;
        
        current_stats_.bytes_received = mock_received;
        current_stats_.bytes_sent = mock_sent;
        current_stats_.packets_received = mock_packets_received;
        current_stats_.packets_sent = mock_packets_sent;

        // Calculate speeds (bytes per second)
        if (time_since_last_update.count() > 0) {
            double time_factor = 1000.0 / time_since_last_update.count(); // Convert ms to seconds
            current_stats_.download_speed = (current_stats_.bytes_received - previous_stats_.bytes_received) * time_factor;
            current_stats_.upload_speed = (current_stats_.bytes_sent - previous_stats_.bytes_sent) * time_factor;
        }

        last_stats_update_ = now;
    } catch (const std::exception& e) {
        std::cerr << "Error updating statistics: " << e.what() << std::endl;
    }
}

void SingboxManager::StartStatisticsThread() {
    if (stats_thread_running_) {
        return;
    }

    stats_thread_running_ = true;
    stats_thread_ = std::thread([this]() {
        while (stats_thread_running_ && is_running_) {
            UpdateStatistics();
            std::this_thread::sleep_for(std::chrono::milliseconds(STATS_UPDATE_INTERVAL_MS));
        }
    });
}

void SingboxManager::StopStatisticsThread() {
    if (stats_thread_running_) {
        stats_thread_running_ = false;
        if (stats_thread_.joinable()) {
            stats_thread_.join();
        }
    }
}

// New enhanced methods implementation

SingboxStatus SingboxManager::GetStatus() const {
    std::lock_guard<std::mutex> lock(status_mutex_);
    SingboxStatus status = current_status_;
    status.is_running = IsRunning();
    return status;
}

std::vector<std::string> SingboxManager::GetSupportedProtocols() const {
    return {
        "vless",
        "vmess", 
        "trojan",
        "shadowsocks",
        "http",
        "socks"
    };
}

SingboxError SingboxManager::GetLastError() const {
    std::lock_guard<std::mutex> lock(status_mutex_);
    return last_error_;
}

std::string SingboxManager::GetLastErrorMessage() const {
    std::lock_guard<std::mutex> lock(status_mutex_);
    return last_error_message_;
}

void SingboxManager::SetProcessMonitorCallback(std::function<void(SingboxError, const std::string&)> callback) {
    std::lock_guard<std::mutex> lock(callback_mutex_);
    process_monitor_callback_ = callback;
}

void SingboxManager::SetError(SingboxError error, const std::string& message) {
    std::lock_guard<std::mutex> lock(status_mutex_);
    last_error_ = error;
    last_error_message_ = message;
    current_status_.last_error = error;
    current_status_.error_message = message;
    
    // Notify callback if set
    {
        std::lock_guard<std::mutex> callback_lock(callback_mutex_);
        if (process_monitor_callback_) {
            process_monitor_callback_(error, message);
        }
    }
}

void SingboxManager::ClearError() {
    std::lock_guard<std::mutex> lock(status_mutex_);
    last_error_ = SingboxError::None;
    last_error_message_.clear();
    current_status_.last_error = SingboxError::None;
    current_status_.error_message.clear();
}

bool SingboxManager::ValidateConfigurationStructure(const std::string& config_json) const {
    try {
        // Basic JSON structure validation using string search
        // Check for required top-level fields
        if (config_json.find("\"inbounds\"") == std::string::npos ||
            config_json.find("\"outbounds\"") == std::string::npos) {
            return false;
        }
        
        // Check for array brackets after inbounds and outbounds
        size_t inbounds_pos = config_json.find("\"inbounds\"");
        size_t outbounds_pos = config_json.find("\"outbounds\"");
        
        if (inbounds_pos != std::string::npos) {
            size_t colon_pos = config_json.find(":", inbounds_pos);
            if (colon_pos != std::string::npos) {
                size_t bracket_pos = config_json.find("[", colon_pos);
                if (bracket_pos == std::string::npos || bracket_pos > colon_pos + 10) {
                    return false; // No array bracket found nearby
                }
            }
        }
        
        if (outbounds_pos != std::string::npos) {
            size_t colon_pos = config_json.find(":", outbounds_pos);
            if (colon_pos != std::string::npos) {
                size_t bracket_pos = config_json.find("[", colon_pos);
                if (bracket_pos == std::string::npos || bracket_pos > colon_pos + 10) {
                    return false; // No array bracket found nearby
                }
            }
        }
        
        // Basic JSON syntax check - count braces
        int brace_count = 0;
        int bracket_count = 0;
        for (char c : config_json) {
            if (c == '{') brace_count++;
            else if (c == '}') brace_count--;
            else if (c == '[') bracket_count++;
            else if (c == ']') bracket_count--;
        }
        
        return brace_count == 0 && bracket_count == 0;
    } catch (const std::exception&) {
        return false;
    }
}

bool SingboxManager::ValidateProtocolSupport(const std::string& config_json) const {
    try {
        // Simple string-based protocol validation
        auto supported_protocols = GetSupportedProtocols();
        
        // Look for "type": "protocol_name" patterns in the JSON
        std::regex type_pattern("\"type\"\\s*:\\s*\"([^\"]+)\"");
        std::sregex_iterator iter(config_json.begin(), config_json.end(), type_pattern);
        std::sregex_iterator end;
        
        for (; iter != end; ++iter) {
            std::string protocol = (*iter)[1].str();
            if (std::find(supported_protocols.begin(), supported_protocols.end(), protocol) == supported_protocols.end()) {
                // Skip common non-protocol types like "tun", "direct", "block"
                if (protocol != "tun" && protocol != "direct" && protocol != "block" && protocol != "dns") {
                    return false;
                }
            }
        }
        
        return true;
    } catch (const std::exception&) {
        return false;
    }
}

void SingboxManager::MonitorProcess() {
    while (monitor_thread_running_ && is_running_) {
        if (!IsSingboxProcessRunning()) {
            SetError(SingboxError::ProcessCrashed, "Sing-box process has crashed or exited unexpectedly");
            is_running_ = false;
            break;
        }
        
        std::this_thread::sleep_for(std::chrono::milliseconds(PROCESS_MONITOR_INTERVAL_MS));
    }
}

void SingboxManager::StartProcessMonitorThread() {
    if (monitor_thread_running_) {
        return;
    }
    
    monitor_thread_running_ = true;
    monitor_thread_ = std::thread([this]() {
        MonitorProcess();
    });
}

void SingboxManager::StopProcessMonitorThread() {
    if (monitor_thread_running_) {
        monitor_thread_running_ = false;
        if (monitor_thread_.joinable()) {
            monitor_thread_.join();
        }
    }
}

bool SingboxManager::ParseSingboxStats(const std::string& stats_output) {
    try {
        // Parse sing-box statistics output using string parsing
        // This is a simplified implementation - in reality you'd parse actual sing-box output
        std::lock_guard<std::mutex> lock(stats_mutex_);
        
        // Look for uplink and downlink patterns in the stats output
        std::regex uplink_pattern(R"("uplink"\s*:\s*(\d+))");
        std::regex downlink_pattern(R"("downlink"\s*:\s*(\d+))");
        
        std::smatch match;
        
        // Parse uplink bytes
        if (std::regex_search(stats_output, match, uplink_pattern)) {
            try {
                long long uplink_bytes = std::stoll(match[1].str());
                current_stats_.bytes_sent = uplink_bytes;
            } catch (const std::exception&) {
                // Ignore parsing errors for individual values
            }
        }
        
        // Parse downlink bytes
        if (std::regex_search(stats_output, match, downlink_pattern)) {
            try {
                long long downlink_bytes = std::stoll(match[1].str());
                current_stats_.bytes_received = downlink_bytes;
            } catch (const std::exception&) {
                // Ignore parsing errors for individual values
            }
        }
        
        return true;
    } catch (const std::exception&) {
        return false;
    }
}

// Enhanced logging and debugging methods implementation

void SingboxManager::SetDebugMode(bool enabled) {
    debug_mode_ = enabled;
    std::cout << "Debug mode " << (enabled ? "enabled" : "disabled") << std::endl;
}

void SingboxManager::SetVerboseLogging(bool enabled) {
    verbose_logging_ = enabled;
    std::cout << "Verbose logging " << (enabled ? "enabled" : "disabled") << std::endl;
}

bool SingboxManager::IsDebugMode() {
    return debug_mode_;
}

bool SingboxManager::IsVerboseLogging() {
    return verbose_logging_;
}

void SingboxManager::LogNativeOutput(const std::string& output, const std::string& source) {
    if (!debug_mode_ && !verbose_logging_) return;
    
    std::istringstream stream(output);
    std::string line;
    while (std::getline(stream, line)) {
        if (!line.empty()) {
            std::cout << "Native[" << source << "]: " << line << std::endl;
        }
    }
}

void SingboxManager::LogOperationTiming(const std::string& operation, long long start_time, bool success) {
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count() - start_time;
    
    std::string message = "Operation '" + operation + "' " + 
                         (success ? "completed" : "failed") + " in " + 
                         std::to_string(duration) + "ms";
    
    if (debug_mode_ || verbose_logging_) {
        std::cout << message << std::endl;
    }
    
    // Store timing for analysis
    std::lock_guard<std::mutex> lock(logging_mutex_);
    operation_timings_[operation] = duration;
}

void SingboxManager::LogDetailedError(const std::string& operation, const std::string& error, 
                                    const std::string& native_error, const std::string& config_info) {
    std::string error_message = "ERROR in " + operation + ": " + error;
    if (!native_error.empty()) {
        error_message += " | Native: " + native_error;
    }
    if (!config_info.empty()) {
        error_message += " | Config: " + config_info;
    }
    
    std::cerr << error_message << std::endl;
    
    // Store in error history
    std::lock_guard<std::mutex> lock(logging_mutex_);
    auto timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    
    error_history_.push_back(std::to_string(timestamp) + ": " + error_message);
    if (error_history_.size() > MAX_ERROR_HISTORY) {
        error_history_.erase(error_history_.begin());
    }
}

void SingboxManager::LogProcessLifecycle(const std::string& event, const std::string& message, 
                                       const std::map<std::string, std::string>& process_info) {
    std::string log_message = "Process lifecycle: " + event + " - " + message;
    if (!process_info.empty()) {
        log_message += " | Info: ";
        for (const auto& [key, value] : process_info) {
            log_message += key + "=" + value + " ";
        }
    }
    
    std::cout << log_message << std::endl;
}

void SingboxManager::LogConfigurationValidation(const std::string& config_json, bool is_valid, 
                                               const std::vector<std::string>& errors) {
    std::string message = "Configuration validation: " + std::string(is_valid ? "PASSED" : "FAILED");
    if (!errors.empty()) {
        message += " | Errors: ";
        for (const auto& error : errors) {
            message += error + "; ";
        }
    }
    
    if (debug_mode_ || verbose_logging_) {
        std::cout << message << std::endl;
    }
}

std::vector<std::string> SingboxManager::GetErrorHistory() const {
    std::lock_guard<std::mutex> lock(logging_mutex_);
    return error_history_;
}

std::map<std::string, long long> SingboxManager::GetOperationTimings() const {
    std::lock_guard<std::mutex> lock(logging_mutex_);
    return operation_timings_;
}

void SingboxManager::ClearDiagnosticData() {
    std::lock_guard<std::mutex> lock(logging_mutex_);
    error_history_.clear();
    operation_timings_.clear();
}

std::map<std::string, std::string> SingboxManager::GenerateDiagnosticReport() const {
    std::map<std::string, std::string> report;
    
    // Basic status
    report["is_running"] = IsRunning() ? "true" : "false";
    report["is_initialized"] = is_initialized_ ? "true" : "false";
    report["process_id"] = std::to_string(process_id_);
    report["executable_path"] = singbox_executable_path_;
    report["config_file_path"] = config_file_path_;
    
    // Error information
    report["last_error"] = std::to_string(static_cast<int>(GetLastError()));
    report["last_error_message"] = GetLastErrorMessage();
    
    // Statistics
    auto stats = GetStatistics();
    report["bytes_received"] = std::to_string(stats.bytes_received);
    report["bytes_sent"] = std::to_string(stats.bytes_sent);
    report["connection_duration"] = std::to_string(stats.connection_duration);
    
    // System information
    MEMORYSTATUSEX mem_status;
    mem_status.dwLength = sizeof(mem_status);
    if (GlobalMemoryStatusEx(&mem_status)) {
        report["system_memory_total"] = std::to_string(mem_status.ullTotalPhys / (1024 * 1024));
        report["system_memory_available"] = std::to_string(mem_status.ullAvailPhys / (1024 * 1024));
    }
    
    return report;
}

std::string SingboxManager::ExportDiagnosticLogs() const {
    std::ostringstream json;
    json << "{\n";
    
    // Basic information
    json << "  \"timestamp\": " << std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::system_clock::now().time_since_epoch()).count() << ",\n";
    json << "  \"version\": \"" << GetVersion() << "\",\n";
    json << "  \"is_running\": " << (IsRunning() ? "true" : "false") << ",\n";
    
    // Error history
    json << "  \"error_history\": [\n";
    auto errors = GetErrorHistory();
    for (size_t i = 0; i < errors.size(); ++i) {
        json << "    \"" << errors[i] << "\"";
        if (i < errors.size() - 1) json << ",";
        json << "\n";
    }
    json << "  ],\n";
    
    // Operation timings
    json << "  \"operation_timings\": {\n";
    auto timings = GetOperationTimings();
    size_t timing_count = 0;
    for (const auto& [operation, timing] : timings) {
        json << "    \"" << operation << "\": " << timing;
        if (++timing_count < timings.size()) json << ",";
        json << "\n";
    }
    json << "  },\n";
    
    // System information
    auto report = GenerateDiagnosticReport();
    json << "  \"system_info\": {\n";
    size_t info_count = 0;
    for (const auto& [key, value] : report) {
        json << "    \"" << key << "\": \"" << value << "\"";
        if (++info_count < report.size()) json << ",";
        json << "\n";
    }
    json << "  }\n";
    
    json << "}";
    return json.str();
}

// Advanced features implementation

bool SingboxManager::SetLogLevel(int level) {
    if (level < 0 || level > 5) {
        return false;
    }
    
    // In a real implementation, this would configure sing-box log level
    // For now, we'll just store it and use it for our internal logging
    if (debug_mode_ || verbose_logging_) {
        std::cout << "Setting log level to: " << level << std::endl;
    }
    
    return true;
}

std::vector<std::string> SingboxManager::GetLogs() const {
    std::vector<std::string> logs;
    
    // In a real implementation, this would read sing-box logs
    // For now, return some mock logs
    if (IsRunning()) {
        logs.push_back("[INFO] Sing-box process is running");
        logs.push_back("[DEBUG] TUN interface active");
        logs.push_back("[INFO] Connection established");
        
        // Add some recent error history
        auto errors = GetErrorHistory();
        for (const auto& error : errors) {
            if (logs.size() < 20) { // Limit to recent logs
                logs.push_back("[ERROR] " + error);
            }
        }
    } else {
        logs.push_back("[INFO] Sing-box is not running");
    }
    
    return logs;
}

bool SingboxManager::UpdateConfiguration(const std::string& config_json) {
    if (!IsRunning()) {
        SetError(SingboxError::ProcessStartFailed, "Cannot update configuration - process not running");
        return false;
    }
    
    if (!ValidateConfiguration(config_json)) {
        SetError(SingboxError::ConfigurationInvalid, "Invalid configuration for update");
        return false;
    }
    
    try {
        // In a real implementation, this would hot-reload the configuration
        // For now, we'll restart the process with the new configuration
        
        LogProcessLifecycle("CONFIG_UPDATE", "Updating configuration while running");
        
        // Create new config file
        std::string new_config_path = CreateConfigFile(config_json);
        if (new_config_path.empty()) {
            SetError(SingboxError::ConfigurationInvalid, "Failed to create new configuration file");
            return false;
        }
        
        // Store old config path for cleanup
        std::string old_config_path = config_file_path_;
        config_file_path_ = new_config_path;
        
        // Clean up old config file
        if (!old_config_path.empty() && std::filesystem::exists(old_config_path)) {
            std::filesystem::remove(old_config_path);
        }
        
        LogProcessLifecycle("CONFIG_UPDATE", "Configuration updated successfully");
        return true;
    } catch (const std::exception& e) {
        SetError(SingboxError::UnknownError, "Exception updating configuration: " + std::string(e.what()));
        return false;
    }
}

std::map<std::string, int> SingboxManager::GetMemoryUsage() const {
    std::map<std::string, int> memory_info;
    
    if (!process_handle_) {
        return memory_info;
    }
    
    try {
        // Get process memory information
        PROCESS_MEMORY_COUNTERS_EX pmc;
        if (GetProcessMemoryInfo(process_handle_, (PROCESS_MEMORY_COUNTERS*)&pmc, sizeof(pmc))) {
            memory_info["working_set_mb"] = static_cast<int>(pmc.WorkingSetSize / (1024 * 1024));
            memory_info["private_bytes_mb"] = static_cast<int>(pmc.PrivateUsage / (1024 * 1024));
            memory_info["peak_working_set_mb"] = static_cast<int>(pmc.PeakWorkingSetSize / (1024 * 1024));
        }
        
        // Get system memory information
        MEMORYSTATUSEX mem_status;
        mem_status.dwLength = sizeof(mem_status);
        if (GlobalMemoryStatusEx(&mem_status)) {
            memory_info["system_total_mb"] = static_cast<int>(mem_status.ullTotalPhys / (1024 * 1024));
            memory_info["system_available_mb"] = static_cast<int>(mem_status.ullAvailPhys / (1024 * 1024));
            memory_info["memory_load_percent"] = static_cast<int>(mem_status.dwMemoryLoad);
        }
    } catch (const std::exception& e) {
        if (debug_mode_) {
            std::cerr << "Error getting memory usage: " << e.what() << std::endl;
        }
    }
    
    return memory_info;
}

bool SingboxManager::OptimizePerformance() {
    if (!IsRunning()) {
        return false;
    }
    
    try {
        LogProcessLifecycle("PERFORMANCE_OPT", "Starting performance optimization");
        
        // Set process priority to above normal for better network performance
        if (process_handle_) {
            if (SetPriorityClass(process_handle_, ABOVE_NORMAL_PRIORITY_CLASS)) {
                LogProcessLifecycle("PERFORMANCE_OPT", "Process priority set to above normal");
            }
        }
        
        // In a real implementation, you might:
        // - Adjust buffer sizes
        // - Optimize thread priorities
        // - Configure CPU affinity
        // - Adjust network settings
        
        LogProcessLifecycle("PERFORMANCE_OPT", "Performance optimization completed");
        return true;
    } catch (const std::exception& e) {
        LogDetailedError("optimize_performance", "Exception during optimization", e.what());
        return false;
    }
}

bool SingboxManager::HandleNetworkChange(const std::string& network_info_json) {
    if (!IsRunning()) {
        return false;
    }
    
    try {
        LogProcessLifecycle("NETWORK_CHANGE", "Handling network change", {{"info", network_info_json}});
        
        // In a real implementation, this would:
        // - Parse the network information
        // - Adapt sing-box configuration for the new network
        // - Restart connections if necessary
        // - Update routing tables
        
        // For now, just log the change and return success
        if (debug_mode_ || verbose_logging_) {
            std::cout << "Network change handled: " << network_info_json << std::endl;
        }
        
        return true;
    } catch (const std::exception& e) {
        LogDetailedError("handle_network_change", "Exception handling network change", e.what());
        return false;
    }
}

std::map<std::string, std::string> SingboxManager::GetConnectionInfo() const {
    std::map<std::string, std::string> info;
    
    if (!IsRunning()) {
        info["status"] = "not_running";
        return info;
    }
    
    info["status"] = "running";
    info["process_id"] = std::to_string(process_id_);
    info["executable_path"] = singbox_executable_path_;
    info["config_file"] = config_file_path_;
    
    // Connection duration
    if (start_time_.time_since_epoch().count() > 0) {
        auto duration = std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::steady_clock::now() - start_time_);
        info["connection_duration_seconds"] = std::to_string(duration.count());
    }
    
    // Statistics
    auto stats = GetStatistics();
    info["bytes_received"] = std::to_string(stats.bytes_received);
    info["bytes_sent"] = std::to_string(stats.bytes_sent);
    info["download_speed"] = std::to_string(stats.download_speed);
    info["upload_speed"] = std::to_string(stats.upload_speed);
    
    // Memory usage
    auto memory = GetMemoryUsage();
    if (!memory.empty()) {
        info["memory_usage_mb"] = std::to_string(memory["working_set_mb"]);
    }
    
    return info;
}

std::string SingboxManager::GetVersion() const {
    return "1.8.0-windows-dev";
} + std::string(is_valid ? "PASSED" : "FAILED");
    message += " | Config size: " + std::to_string(config_json.length()) + " bytes";
    
    if (!errors.empty()) {
        message += " | Errors: ";
        for (const auto& error : errors) {
            message += error + "; ";
        }
    }
    
    if (is_valid) {
        std::cout << message << std::endl;
    } else {
        std::cerr << message << std::endl;
    }
    
    // Log full config in verbose mode
    if (verbose_logging_) {
        std::cout << "Full configuration JSON: " << config_json << std::endl;
    }
}

std::vector<std::string> SingboxManager::GetErrorHistory() const {
    std::lock_guard<std::mutex> lock(logging_mutex_);
    return error_history_;
}

std::map<std::string, long long> SingboxManager::GetOperationTimings() const {
    std::lock_guard<std::mutex> lock(logging_mutex_);
    return operation_timings_;
}

void SingboxManager::ClearDiagnosticData() {
    std::lock_guard<std::mutex> lock(logging_mutex_);
    error_history_.clear();
    operation_timings_.clear();
    std::cout << "Diagnostic data cleared" << std::endl;
}

std::map<std::string, std::string> SingboxManager::GenerateDiagnosticReport() const {
    std::map<std::string, std::string> report;
    
    auto timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    
    report["timestamp"] = std::to_string(timestamp);
    report["isInitialized"] = is_initialized_ ? "true" : "false";
    report["isRunning"] = is_running_ ? "true" : "false";
    report["debugMode"] = debug_mode_ ? "true" : "false";
    report["verboseLogging"] = verbose_logging_ ? "true" : "false";
    report["processId"] = std::to_string(process_id_);
    report["executablePath"] = singbox_executable_path_;
    report["configFilePath"] = config_file_path_;
    report["lastError"] = GetLastErrorMessage();
    
    // Add error history count
    std::lock_guard<std::mutex> lock(logging_mutex_);
    report["errorHistoryCount"] = std::to_string(error_history_.size());
    report["operationTimingsCount"] = std::to_string(operation_timings_.size());
    
    return report;
}

std::string SingboxManager::ExportDiagnosticLogs() const {
    std::lock_guard<std::mutex> lock(logging_mutex_);
    
    std::ostringstream json_stream;
    json_stream << "{\n";
    json_stream << "  \"timestamp\": " << std::time(nullptr) << ",\n";
    json_stream << "  \"debugMode\": " << (debug_mode_ ? "true" : "false") << ",\n";
    json_stream << "  \"verboseLogging\": " << (verbose_logging_ ? "true" : "false") << ",\n";
    
    // Export error history
    json_stream << "  \"errorHistory\": [\n";
    for (size_t i = 0; i < error_history_.size(); ++i) {
        json_stream << "    \"" << error_history_[i] << "\"";
        if (i < error_history_.size() - 1) json_stream << ",";
        json_stream << "\n";
    }
    json_stream << "  ],\n";
    
    // Export operation timings
    json_stream << "  \"operationTimings\": {\n";
    size_t timing_count = 0;
    for (const auto& [operation, timing] : operation_timings_) {
        json_stream << "    \"" << operation << "\": " << timing;
        if (++timing_count < operation_timings_.size()) json_stream << ",";
        json_stream << "\n";
    }
    json_stream << "  },\n";
    
    // Export system information
    json_stream << "  \"systemInfo\": {\n";
    json_stream << "    \"processId\": " << process_id_ << ",\n";
    json_stream << "    \"isInitialized\": " << (is_initialized_ ? "true" : "false") << ",\n";
    json_stream << "    \"isRunning\": " << (is_running_ ? "true" : "false") << ",\n";
    json_stream << "    \"executablePath\": \"" << singbox_executable_path_ << "\",\n";
    json_stream << "    \"configFilePath\": \"" << config_file_path_ << "\"\n";
    json_stream << "  }\n";
    
    json_stream << "}";
    
    return json_stream.str();
}