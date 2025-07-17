#include <android/log.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <pthread.h>

#define TAG "SingBoxLogging"
#define MAX_LOG_ENTRIES 1000
#define MAX_LOG_LENGTH 512

// Log entry structure
typedef struct {
    time_t timestamp;
    int level;
    char message[MAX_LOG_LENGTH];
} log_entry_t;

// Global log buffer
static log_entry_t log_buffer[MAX_LOG_ENTRIES];
static int log_head = 0;
static int log_count = 0;
static pthread_mutex_t log_mutex = PTHREAD_MUTEX_INITIALIZER;

// Log level definitions
typedef enum {
    LOG_LEVEL_TRACE = 0,
    LOG_LEVEL_DEBUG = 1,
    LOG_LEVEL_INFO = 2,
    LOG_LEVEL_WARN = 3,
    LOG_LEVEL_ERROR = 4,
    LOG_LEVEL_FATAL = 5
} log_level_t;

static int current_log_level = LOG_LEVEL_INFO;

// Log level names
static const char* log_level_names[] = {
    "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL"
};

/**
 * Set the current log level
 */
void singbox_set_log_level(int level) {
    pthread_mutex_lock(&log_mutex);
    if (level >= LOG_LEVEL_TRACE && level <= LOG_LEVEL_FATAL) {
        current_log_level = level;
        __android_log_print(ANDROID_LOG_INFO, TAG, "Log level set to %s", log_level_names[level]);
    }
    pthread_mutex_unlock(&log_mutex);
}

/**
 * Get the current log level
 */
int singbox_get_log_level() {
    pthread_mutex_lock(&log_mutex);
    int level = current_log_level;
    pthread_mutex_unlock(&log_mutex);
    return level;
}

/**
 * Add a log entry to the circular buffer
 */
static void add_log_entry(int level, const char* message) {
    pthread_mutex_lock(&log_mutex);
    
    // Don't log if level is below current threshold
    if (level < current_log_level) {
        pthread_mutex_unlock(&log_mutex);
        return;
    }
    
    // Add to circular buffer
    log_buffer[log_head].timestamp = time(NULL);
    log_buffer[log_head].level = level;
    strncpy(log_buffer[log_head].message, message, MAX_LOG_LENGTH - 1);
    log_buffer[log_head].message[MAX_LOG_LENGTH - 1] = '\0';
    
    log_head = (log_head + 1) % MAX_LOG_ENTRIES;
    if (log_count < MAX_LOG_ENTRIES) {
        log_count++;
    }
    
    pthread_mutex_unlock(&log_mutex);
}

/**
 * Log a message with specified level
 */
void singbox_log(int level, const char* format, ...) {
    if (level < current_log_level) {
        return;
    }
    
    char message[MAX_LOG_LENGTH];
    va_list args;
    va_start(args, format);
    vsnprintf(message, sizeof(message), format, args);
    va_end(args);
    
    // Log to Android logcat
    int android_level;
    switch (level) {
        case LOG_LEVEL_TRACE:
        case LOG_LEVEL_DEBUG:
            android_level = ANDROID_LOG_DEBUG;
            break;
        case LOG_LEVEL_INFO:
            android_level = ANDROID_LOG_INFO;
            break;
        case LOG_LEVEL_WARN:
            android_level = ANDROID_LOG_WARN;
            break;
        case LOG_LEVEL_ERROR:
            android_level = ANDROID_LOG_ERROR;
            break;
        case LOG_LEVEL_FATAL:
            android_level = ANDROID_LOG_FATAL;
            break;
        default:
            android_level = ANDROID_LOG_INFO;
    }
    
    __android_log_print(android_level, TAG, "[%s] %s", log_level_names[level], message);
    
    // Add to internal buffer
    add_log_entry(level, message);
}

/**
 * Get logs as JSON string
 * Caller is responsible for freeing the returned string
 */
char* singbox_get_logs_json() {
    pthread_mutex_lock(&log_mutex);
    
    // Calculate required buffer size
    size_t buffer_size = 1024; // Base size for JSON structure
    for (int i = 0; i < log_count; i++) {
        buffer_size += strlen(log_buffer[i].message) + 100; // Extra space for JSON formatting
    }
    
    char* json_buffer = malloc(buffer_size);
    if (!json_buffer) {
        pthread_mutex_unlock(&log_mutex);
        return NULL;
    }
    
    strcpy(json_buffer, "{\"logs\":[");
    
    int start_index = (log_count == MAX_LOG_ENTRIES) ? log_head : 0;
    for (int i = 0; i < log_count; i++) {
        int index = (start_index + i) % MAX_LOG_ENTRIES;
        
        if (i > 0) {
            strcat(json_buffer, ",");
        }
        
        // Format timestamp
        struct tm* tm_info = localtime(&log_buffer[index].timestamp);
        char timestamp_str[32];
        strftime(timestamp_str, sizeof(timestamp_str), "%Y-%m-%d %H:%M:%S", tm_info);
        
        // Escape message for JSON
        char escaped_message[MAX_LOG_LENGTH * 2];
        const char* src = log_buffer[index].message;
        char* dst = escaped_message;
        
        while (*src && (size_t)(dst - escaped_message) < sizeof(escaped_message) - 2) {
            if (*src == '"' || *src == '\\') {
                *dst++ = '\\';
            }
            *dst++ = *src++;
        }
        *dst = '\0';
        
        // Add log entry to JSON
        char entry[MAX_LOG_LENGTH * 3];
        snprintf(entry, sizeof(entry),
            "{\"timestamp\":\"%s\",\"level\":\"%s\",\"message\":\"%s\"}",
            timestamp_str,
            log_level_names[log_buffer[index].level],
            escaped_message
        );
        
        strcat(json_buffer, entry);
    }
    
    strcat(json_buffer, "]}");
    
    pthread_mutex_unlock(&log_mutex);
    return json_buffer;
}

/**
 * Clear all log entries
 */
void singbox_clear_logs() {
    pthread_mutex_lock(&log_mutex);
    log_head = 0;
    log_count = 0;
    __android_log_print(ANDROID_LOG_INFO, TAG, "Log buffer cleared");
    pthread_mutex_unlock(&log_mutex);
}

/**
 * Get log statistics
 */
void singbox_get_log_stats(int* total_entries, int* current_level) {
    pthread_mutex_lock(&log_mutex);
    if (total_entries) {
        *total_entries = log_count;
    }
    if (current_level) {
        *current_level = current_log_level;
    }
    pthread_mutex_unlock(&log_mutex);
}

/**
 * Initialize logging system
 */
void singbox_logging_init() {
    pthread_mutex_lock(&log_mutex);
    log_head = 0;
    log_count = 0;
    current_log_level = LOG_LEVEL_INFO;
    __android_log_print(ANDROID_LOG_INFO, TAG, "Sing-box logging system initialized");
    pthread_mutex_unlock(&log_mutex);
}

/**
 * Cleanup logging system
 */
void singbox_logging_cleanup() {
    pthread_mutex_lock(&log_mutex);
    log_head = 0;
    log_count = 0;
    __android_log_print(ANDROID_LOG_INFO, TAG, "Sing-box logging system cleaned up");
    pthread_mutex_unlock(&log_mutex);
}