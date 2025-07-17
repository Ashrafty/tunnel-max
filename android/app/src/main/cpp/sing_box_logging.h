#ifndef SING_BOX_LOGGING_H
#define SING_BOX_LOGGING_H

#ifdef __cplusplus
extern "C" {
#endif

// Log level definitions
#define SINGBOX_LOG_TRACE 0
#define SINGBOX_LOG_DEBUG 1
#define SINGBOX_LOG_INFO  2
#define SINGBOX_LOG_WARN  3
#define SINGBOX_LOG_ERROR 4
#define SINGBOX_LOG_FATAL 5

/**
 * Initialize the logging system
 */
void singbox_logging_init(void);

/**
 * Cleanup the logging system
 */
void singbox_logging_cleanup(void);

/**
 * Set the current log level
 * @param level Log level (0=TRACE, 1=DEBUG, 2=INFO, 3=WARN, 4=ERROR, 5=FATAL)
 */
void singbox_set_log_level(int level);

/**
 * Get the current log level
 * @return Current log level
 */
int singbox_get_log_level(void);

/**
 * Log a message with specified level
 * @param level Log level
 * @param format Printf-style format string
 * @param ... Format arguments
 */
void singbox_log(int level, const char* format, ...);

/**
 * Get logs as JSON string
 * @return JSON string containing log entries (caller must free)
 */
char* singbox_get_logs_json(void);

/**
 * Clear all log entries
 */
void singbox_clear_logs(void);

/**
 * Get log statistics
 * @param total_entries Pointer to store total number of log entries
 * @param current_level Pointer to store current log level
 */
void singbox_get_log_stats(int* total_entries, int* current_level);

// Convenience macros for logging
#define SINGBOX_LOG_T(fmt, ...) singbox_log(SINGBOX_LOG_TRACE, fmt, ##__VA_ARGS__)
#define SINGBOX_LOG_D(fmt, ...) singbox_log(SINGBOX_LOG_DEBUG, fmt, ##__VA_ARGS__)
#define SINGBOX_LOG_I(fmt, ...) singbox_log(SINGBOX_LOG_INFO, fmt, ##__VA_ARGS__)
#define SINGBOX_LOG_W(fmt, ...) singbox_log(SINGBOX_LOG_WARN, fmt, ##__VA_ARGS__)
#define SINGBOX_LOG_E(fmt, ...) singbox_log(SINGBOX_LOG_ERROR, fmt, ##__VA_ARGS__)
#define SINGBOX_LOG_F(fmt, ...) singbox_log(SINGBOX_LOG_FATAL, fmt, ##__VA_ARGS__)

#ifdef __cplusplus
}
#endif

#endif // SING_BOX_LOGGING_H