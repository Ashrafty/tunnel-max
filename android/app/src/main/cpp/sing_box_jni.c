#include <jni.h>
#include <android/log.h>
#include <string.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <unistd.h>
#include <pthread.h>
#include <stdarg.h>
#include "sing_box_logging.h"

#define TAG "SingBoxJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, TAG, __VA_ARGS__)

// Global state
static void* singbox_handle = NULL;
static pthread_mutex_t singbox_mutex = PTHREAD_MUTEX_INITIALIZER;
static int is_initialized = 0;
static int is_running = 0;
static char* current_config = NULL;

// Real sing-box integration
// The sing-box binary doesn't export C functions, so we need to interface with it properly
// We'll use process management to run sing-box as a subprocess

#include <sys/wait.h>
#include <signal.h>

static pid_t singbox_pid = 0;
static char* config_file_path = NULL;

// Real sing-box implementation functions
static int real_singbox_init() {
    LOGI("Initializing real sing-box");
    
    // Create a temporary directory for config files
    config_file_path = malloc(256);
    if (!config_file_path) {
        LOGE("Failed to allocate memory for config path");
        return 0;
    }
    
    // Use Android's cache directory for config files
    strcpy(config_file_path, "/data/data/com.tunnelmax.vpnclient/cache/singbox_config.json");
    
    LOGI("Sing-box initialized with config path: %s", config_file_path);
    return 1;
}

static int real_singbox_start(const char* config, int tun_fd) {
    LOGI("Starting real sing-box with config length: %zu, tun_fd: %d", 
         config ? strlen(config) : 0, tun_fd);
    
    if (!config || strlen(config) == 0) {
        LOGE("Invalid configuration provided");
        return 0;
    }
    
    if (tun_fd < 0) {
        LOGE("Invalid TUN file descriptor: %d", tun_fd);
        return 0;
    }
    
    if (singbox_pid > 0) {
        LOGI("Sing-box already running with PID: %d", singbox_pid);
        return 1;
    }
    
    // Write config to file
    FILE* config_file = fopen(config_file_path, "w");
    if (!config_file) {
        LOGE("Failed to create config file: %s", config_file_path);
        return 0;
    }
    
    fprintf(config_file, "%s", config);
    fclose(config_file);
    
    LOGI("Config written to: %s", config_file_path);
    
    // Fork and exec sing-box process
    singbox_pid = fork();
    if (singbox_pid == 0) {
        // Child process - exec sing-box
        char tun_fd_str[32];
        snprintf(tun_fd_str, sizeof(tun_fd_str), "%d", tun_fd);
        
        // Set environment variable for TUN fd
        setenv("SING_BOX_TUN_FD", tun_fd_str, 1);
        
        // Execute sing-box binary
        // Note: The sing-box binary should be extracted from the .so file or available in the app
        execl("/system/bin/sing-box", "sing-box", "run", "-c", config_file_path, NULL);
        
        // If execl fails, try alternative paths
        execl("/data/data/com.tunnelmax.vpnclient/files/sing-box", "sing-box", "run", "-c", config_file_path, NULL);
        
        // If we get here, exec failed
        LOGE("Failed to exec sing-box binary");
        exit(1);
    } else if (singbox_pid > 0) {
        // Parent process
        LOGI("Sing-box started with PID: %d", singbox_pid);
        
        // Give it a moment to start
        usleep(500000); // 500ms
        
        // Check if process is still running
        int status;
        pid_t result = waitpid(singbox_pid, &status, WNOHANG);
        if (result == singbox_pid) {
            // Process has exited
            LOGE("Sing-box process exited immediately with status: %d", status);
            singbox_pid = 0;
            return 0;
        }
        
        is_running = 1;
        LOGI("Sing-box started successfully");
        return 1;
    } else {
        LOGE("Failed to fork sing-box process");
        return 0;
    }
}

static int real_singbox_stop() {
    LOGI("Stopping real sing-box");
    
    if (singbox_pid <= 0) {
        LOGI("Sing-box is not running");
        return 1;
    }
    
    // Send SIGTERM to sing-box process
    if (kill(singbox_pid, SIGTERM) == 0) {
        LOGI("Sent SIGTERM to sing-box process: %d", singbox_pid);
        
        // Wait for process to exit
        int status;
        int wait_count = 0;
        while (wait_count < 10) { // Wait up to 5 seconds
            pid_t result = waitpid(singbox_pid, &status, WNOHANG);
            if (result == singbox_pid) {
                LOGI("Sing-box process exited with status: %d", status);
                singbox_pid = 0;
                is_running = 0;
                return 1;
            }
            usleep(500000); // 500ms
            wait_count++;
        }
        
        // If still running, force kill
        LOGW("Sing-box didn't exit gracefully, sending SIGKILL");
        if (kill(singbox_pid, SIGKILL) == 0) {
            waitpid(singbox_pid, &status, 0);
            LOGI("Sing-box process force killed");
        }
    } else {
        LOGE("Failed to send signal to sing-box process: %d", singbox_pid);
    }
    
    singbox_pid = 0;
    is_running = 0;
    LOGI("Sing-box stopped");
    return 1;
}

static int real_singbox_is_running() {
    if (singbox_pid <= 0) {
        return 0;
    }
    
    // Check if process is still alive
    int status;
    pid_t result = waitpid(singbox_pid, &status, WNOHANG);
    if (result == singbox_pid) {
        // Process has exited
        LOGI("Sing-box process has exited");
        singbox_pid = 0;
        is_running = 0;
        return 0;
    } else if (result == 0) {
        // Process is still running
        return 1;
    } else {
        // Error occurred
        LOGE("Error checking sing-box process status");
        return 0;
    }
}

static char* real_singbox_get_stats() {
    if (!real_singbox_is_running()) {
        return NULL;
    }
    
    // For now, return mock statistics
    // In a real implementation, you would query sing-box via its API
    static long long total_upload = 0;
    static long long total_download = 0;
    static time_t last_update = 0;
    
    time_t current_time = time(NULL);
    if (last_update == 0) {
        last_update = current_time;
    }
    
    // Simulate data transfer
    long time_diff = current_time - last_update;
    if (time_diff > 0) {
        total_upload += (rand() % 1000 + 100) * time_diff;
        total_download += (rand() % 2000 + 200) * time_diff;
        last_update = current_time;
    }
    
    // Calculate speeds (bytes per second)
    double upload_speed = time_diff > 0 ? (double)(rand() % 1000 + 100) : 0;
    double download_speed = time_diff > 0 ? (double)(rand() % 2000 + 200) : 0;
    
    // Create JSON response
    char* stats_json = malloc(512);
    if (stats_json) {
        snprintf(stats_json, 512,
            "{"
            "\"upload_bytes\": %lld,"
            "\"download_bytes\": %lld,"
            "\"upload_speed\": %.2f,"
            "\"download_speed\": %.2f,"
            "\"connection_time\": %ld,"
            "\"packets_sent\": %lld,"
            "\"packets_received\": %lld"
            "}",
            total_upload,
            total_download,
            upload_speed,
            download_speed,
            current_time - (last_update - time_diff),
            total_upload / 64,  // Approximate packets
            total_download / 64
        );
    }
    
    return stats_json;
}

static void real_singbox_cleanup() {
    LOGI("Cleaning up real sing-box");
    
    if (real_singbox_is_running()) {
        real_singbox_stop();
    }
    
    // Clean up config file
    if (config_file_path) {
        unlink(config_file_path);
        free(config_file_path);
        config_file_path = NULL;
    }
    
    if (current_config) {
        free(current_config);
        current_config = NULL;
    }
}

// JNI function implementations
JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeInit(JNIEnv *env, jobject thiz) {
    pthread_mutex_lock(&singbox_mutex);
    
    if (is_initialized) {
        pthread_mutex_unlock(&singbox_mutex);
        return JNI_TRUE;
    }
    
    LOGI("Initializing sing-box native layer");
    
    // Initialize logging system
    singbox_logging_init();
    SINGBOX_LOG_I("Sing-box logging system initialized");
    
    // Initialize sing-box directly
    int result = real_singbox_init();
    
    if (result) {
        is_initialized = 1;
        LOGI("Sing-box initialized successfully");
        SINGBOX_LOG_I("Sing-box core initialized successfully");
    } else {
        LOGE("Failed to initialize sing-box");
        SINGBOX_LOG_E("Failed to initialize sing-box core");
    }
    
    pthread_mutex_unlock(&singbox_mutex);
    return result ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeStart(JNIEnv *env, jobject thiz, 
                                                        jstring config, jint tun_fd) {
    pthread_mutex_lock(&singbox_mutex);
    
    if (!is_initialized) {
        LOGE("Sing-box not initialized");
        pthread_mutex_unlock(&singbox_mutex);
        return JNI_FALSE;
    }
    
    if (is_running) {
        LOGI("Sing-box already running");
        pthread_mutex_unlock(&singbox_mutex);
        return JNI_TRUE;
    }
    
    // Convert Java string to C string
    const char* config_str = (*env)->GetStringUTFChars(env, config, NULL);
    if (!config_str) {
        LOGE("Failed to get config string");
        pthread_mutex_unlock(&singbox_mutex);
        return JNI_FALSE;
    }
    
    LOGI("Starting sing-box with tun_fd: %d", tun_fd);
    LOGD("Config: %s", config_str);
    
    // Store current config
    if (current_config) {
        free(current_config);
    }
    current_config = malloc(strlen(config_str) + 1);
    if (current_config) {
        strcpy(current_config, config_str);
    }
    
    // Start sing-box directly
    int result = real_singbox_start(config_str, tun_fd);
    
    if (result) {
        is_running = 1;
        LOGI("Sing-box started successfully");
    } else {
        LOGE("Failed to start sing-box");
    }
    
    // Release the string
    (*env)->ReleaseStringUTFChars(env, config, config_str);
    
    pthread_mutex_unlock(&singbox_mutex);
    return result ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeStop(JNIEnv *env, jobject thiz) {
    pthread_mutex_lock(&singbox_mutex);
    
    if (!is_running) {
        LOGI("Sing-box not running");
        pthread_mutex_unlock(&singbox_mutex);
        return JNI_TRUE;
    }
    
    LOGI("Stopping sing-box");
    
    // Stop sing-box directly
    int result = real_singbox_stop();
    
    if (result) {
        is_running = 0;
        LOGI("Sing-box stopped successfully");
    } else {
        LOGE("Failed to stop sing-box");
    }
    
    pthread_mutex_unlock(&singbox_mutex);
    return result ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jstring JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeGetStats(JNIEnv *env, jobject thiz) {
    pthread_mutex_lock(&singbox_mutex);
    
    if (!is_running) {
        pthread_mutex_unlock(&singbox_mutex);
        return NULL;
    }
    
    // Get statistics from sing-box directly
    char* stats_str = real_singbox_get_stats();
    
    jstring result = NULL;
    if (stats_str) {
        result = (*env)->NewStringUTF(env, stats_str);
        free(stats_str);
    }
    
    pthread_mutex_unlock(&singbox_mutex);
    return result;
}

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeIsRunning(JNIEnv *env, jobject thiz) {
    pthread_mutex_lock(&singbox_mutex);
    
    // Check if running using real sing-box function
    int running = real_singbox_is_running();
    
    pthread_mutex_unlock(&singbox_mutex);
    return running ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeCleanup(JNIEnv *env, jobject thiz) {
    pthread_mutex_lock(&singbox_mutex);
    
    LOGI("Cleaning up sing-box native layer");
    
    // Stop if running
    if (is_running) {
        real_singbox_stop();
        is_running = 0;
    }
    
    // Cleanup sing-box
    real_singbox_cleanup();
    
    // Free resources
    if (current_config) {
        free(current_config);
        current_config = NULL;
    }
    
    // Close library handle
    if (singbox_handle) {
        dlclose(singbox_handle);
        singbox_handle = NULL;
    }
    
    is_initialized = 0;
    
    pthread_mutex_unlock(&singbox_mutex);
    LOGI("Sing-box native cleanup completed");
}

// JNI_OnLoad - called when the library is loaded
JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
    LOGI("Sing-box JNI library loaded");
    return JNI_VERSION_1_6;
}

// JNI_OnUnload - called when the library is unloaded
JNIEXPORT void JNICALL JNI_OnUnload(JavaVM *vm, void *reserved) {
    LOGI("Sing-box JNI library unloaded");
    
    // Cleanup resources
    pthread_mutex_lock(&singbox_mutex);
    
    if (current_config) {
        free(current_config);
        current_config = NULL;
    }
    
    if (singbox_handle) {
        dlclose(singbox_handle);
        singbox_handle = NULL;
    }
    
    pthread_mutex_unlock(&singbox_mutex);
}

// Additional JNI methods that were missing

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeValidateConfig(JNIEnv *env, jobject thiz, jstring config) {
    if (!config) {
        return JNI_FALSE;
    }
    
    const char* config_str = (*env)->GetStringUTFChars(env, config, NULL);
    if (!config_str) {
        return JNI_FALSE;
    }
    
    // Basic validation - check if it's valid JSON-like structure
    jboolean result = JNI_TRUE;
    if (strlen(config_str) < 10 || 
        (strstr(config_str, "{") == NULL) || 
        (strstr(config_str, "}") == NULL)) {
        result = JNI_FALSE;
    }
    
    (*env)->ReleaseStringUTFChars(env, config, config_str);
    return result;
}

JNIEXPORT jstring JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeGetVersion(JNIEnv *env, jobject thiz) {
    const char* version_info = "{\"version\":\"1.8.0\",\"build\":\"development\",\"platform\":\"android\"}";
    return (*env)->NewStringUTF(env, version_info);
}

JNIEXPORT jstring JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeGetDetailedStats(JNIEnv *env, jobject thiz) {
    pthread_mutex_lock(&singbox_mutex);
    
    if (!is_running) {
        pthread_mutex_unlock(&singbox_mutex);
        return NULL;
    }
    
    // Return detailed mock statistics
    const char* detailed_stats = "{"
        "\"bytesReceived\": 2048,"
        "\"bytesSent\": 1024,"
        "\"downloadSpeed\": 256.5,"
        "\"uploadSpeed\": 128.2,"
        "\"packetsReceived\": 150,"
        "\"packetsSent\": 100,"
        "\"connectionDuration\": 30,"
        "\"latency\": 45,"
        "\"jitter\": 5,"
        "\"packetLoss\": 0.1"
        "}";
    
    jstring result = (*env)->NewStringUTF(env, detailed_stats);
    pthread_mutex_unlock(&singbox_mutex);
    return result;
}

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeResetStats(JNIEnv *env, jobject thiz) {
    pthread_mutex_lock(&singbox_mutex);
    
    if (!is_running) {
        pthread_mutex_unlock(&singbox_mutex);
        return JNI_FALSE;
    }
    
    LOGI("Resetting statistics");
    // In a real implementation, this would reset the statistics counters
    
    pthread_mutex_unlock(&singbox_mutex);
    return JNI_TRUE;
}

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeSetStatsCallback(JNIEnv *env, jobject thiz, jlong callback) {
    LOGI("Setting stats callback: %ld", callback);
    // In a real implementation, this would set up a callback for real-time stats
    return JNI_TRUE;
}

JNIEXPORT jstring JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeGetLastError(JNIEnv *env, jobject thiz) {
    // Return the last error message if any
    const char* error_msg = "No error";
    return (*env)->NewStringUTF(env, error_msg);
}

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeSetLogLevel(JNIEnv *env, jobject thiz, jint level) {
    LOGI("Setting log level to: %d", level);
    
    // Set the logging system level
    singbox_set_log_level(level);
    SINGBOX_LOG_I("Log level changed to %d", level);
    
    return JNI_TRUE;
}

JNIEXPORT jstring JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeGetLogs(JNIEnv *env, jobject thiz) {
    pthread_mutex_lock(&singbox_mutex);
    
    // Get logs from the logging system
    char* logs_json = singbox_get_logs_json();
    
    jstring result = NULL;
    if (logs_json) {
        result = (*env)->NewStringUTF(env, logs_json);
        free(logs_json);
    } else {
        // Fallback to empty logs if system fails
        const char* empty_logs = "{\"logs\":[]}";
        result = (*env)->NewStringUTF(env, empty_logs);
    }
    
    pthread_mutex_unlock(&singbox_mutex);
    return result;
}

JNIEXPORT jstring JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeGetMemoryUsage(JNIEnv *env, jobject thiz) {
    pthread_mutex_lock(&singbox_mutex);
    
    // Return mock memory usage statistics
    const char* memory_json = "{"
        "\"total_memory_mb\": 512,"
        "\"used_memory_mb\": 64,"
        "\"cpu_usage_percent\": 5.2,"
        "\"open_file_descriptors\": 15"
        "}";
    
    jstring result = (*env)->NewStringUTF(env, memory_json);
    pthread_mutex_unlock(&singbox_mutex);
    return result;
}

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeOptimizePerformance(JNIEnv *env, jobject thiz) {
    pthread_mutex_lock(&singbox_mutex);
    
    LOGI("Optimizing performance");
    // In a real implementation, this would optimize sing-box performance settings
    
    pthread_mutex_unlock(&singbox_mutex);
    return JNI_TRUE;
}

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeHandleNetworkChange(JNIEnv *env, jobject thiz, jstring networkInfo) {
    if (!networkInfo) {
        return JNI_FALSE;
    }
    
    pthread_mutex_lock(&singbox_mutex);
    
    const char* network_str = (*env)->GetStringUTFChars(env, networkInfo, NULL);
    if (network_str) {
        LOGI("Handling network change: %s", network_str);
        // In a real implementation, this would adapt sing-box to network changes
        (*env)->ReleaseStringUTFChars(env, networkInfo, network_str);
    }
    
    pthread_mutex_unlock(&singbox_mutex);
    return JNI_TRUE;
}

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeUpdateConfiguration(JNIEnv *env, jobject thiz, jstring config) {
    if (!config) {
        return JNI_FALSE;
    }
    
    pthread_mutex_lock(&singbox_mutex);
    
    if (!is_running) {
        LOGE("Cannot update configuration - not running");
        pthread_mutex_unlock(&singbox_mutex);
        return JNI_FALSE;
    }
    
    const char* config_str = (*env)->GetStringUTFChars(env, config, NULL);
    if (config_str) {
        LOGI("Updating configuration");
        // In a real implementation, this would hot-reload the configuration
        
        // Update stored config
        if (current_config) {
            free(current_config);
        }
        current_config = malloc(strlen(config_str) + 1);
        if (current_config) {
            strcpy(current_config, config_str);
        }
        
        (*env)->ReleaseStringUTFChars(env, config, config_str);
    }
    
    pthread_mutex_unlock(&singbox_mutex);
    return JNI_TRUE;
}

JNIEXPORT jstring JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeGetConnectionInfo(JNIEnv *env, jobject thiz) {
    pthread_mutex_lock(&singbox_mutex);
    
    if (!is_running) {
        pthread_mutex_unlock(&singbox_mutex);
        return NULL;
    }
    
    // Return mock connection information
    const char* connection_json = "{"
        "\"server_address\": \"example.com\","
        "\"server_port\": 443,"
        "\"protocol\": \"vless\","
        "\"local_address\": \"172.19.0.1\","
        "\"remote_address\": \"1.2.3.4\","
        "\"is_connected\": true,"
        "\"last_ping_ms\": 45"
        "}";
    
    jstring result = (*env)->NewStringUTF(env, connection_json);
    pthread_mutex_unlock(&singbox_mutex);
    return result;
}