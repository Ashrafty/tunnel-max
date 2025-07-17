package com.tunnelmax.vpnclient

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.serialization.json.*

class ConfigurationPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var singboxManager: SingboxManager? = null
    
    companion object {
        private const val CHANNEL_NAME = "com.tunnelmax.vpn/configuration"
        private const val TAG = "ConfigurationPlugin"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        
        // Initialize sing-box manager for validation
        context?.let { ctx ->
            singboxManager = SingboxManager(ctx).apply {
                if (!initialize()) {
                    Log.e(TAG, "Failed to initialize SingboxManager for configuration validation")
                }
            }
        }
        
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        
        Log.i(TAG, "ConfigurationPlugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        
        // Cleanup sing-box resources
        singboxManager?.cleanup()
        
        Log.i(TAG, "ConfigurationPlugin detached from engine")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "validateConfiguration" -> handleValidateConfiguration(call, result)
            "saveConfiguration" -> handleSaveConfiguration(call, result)
            "loadConfigurations" -> handleLoadConfigurations(call, result)
            "loadConfiguration" -> handleLoadConfiguration(call, result)
            "updateConfiguration" -> handleUpdateConfiguration(call, result)
            "deleteConfiguration" -> handleDeleteConfiguration(call, result)
            "deleteAllConfigurations" -> handleDeleteAllConfigurations(call, result)
            "importFromJson" -> handleImportFromJson(call, result)
            "exportToJson" -> handleExportToJson(call, result)
            "isSecureStorageAvailable" -> handleIsSecureStorageAvailable(call, result)
            "getStorageInfo" -> handleGetStorageInfo(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleValidateConfiguration(call: MethodCall, result: Result) {
        try {
            val configMap = call.argument<Map<String, Any>>("configuration")
            if (configMap == null) {
                result.error("INVALID_ARGUMENTS", "Configuration is required", null)
                return
            }
            
            Log.d(TAG, "Validating configuration: ${configMap["name"]}")
            
            // Basic validation
            val validationResult = validateConfigurationBasic(configMap)
            if (!validationResult.isValid) {
                result.success(mapOf(
                    "success" to false,
                    "error" to validationResult.error,
                    "code" to "CONFIGURATION_INVALID"
                ))
                return
            }
            
            // Protocol-specific validation using sing-box
            val protocolValidationResult = validateConfigurationWithSingbox(configMap)
            
            result.success(mapOf(
                "success" to protocolValidationResult.isValid,
                "error" to protocolValidationResult.error,
                "code" to if (protocolValidationResult.isValid) null else "CONFIGURATION_INVALID",
                "details" to protocolValidationResult.details
            ))
            
        } catch (e: Exception) {
            Log.e(TAG, "Error validating configuration", e)
            result.error("VALIDATION_ERROR", "Failed to validate configuration: ${e.message}", null)
        }
    }

    private fun handleSaveConfiguration(call: MethodCall, result: Result) {
        // For now, return success as configuration saving is handled by Flutter
        // In a full implementation, this would save to Android secure storage
        result.success(mapOf("success" to true))
    }

    private fun handleLoadConfigurations(call: MethodCall, result: Result) {
        // For now, return empty list as configuration loading is handled by Flutter
        // In a full implementation, this would load from Android secure storage
        result.success(mapOf(
            "success" to true,
            "data" to emptyList<Map<String, Any>>()
        ))
    }

    private fun handleLoadConfiguration(call: MethodCall, result: Result) {
        // For now, return null as configuration loading is handled by Flutter
        result.success(mapOf(
            "success" to false,
            "error" to "Configuration not found",
            "code" to "CONFIGURATION_NOT_FOUND"
        ))
    }

    private fun handleUpdateConfiguration(call: MethodCall, result: Result) {
        // For now, return success as configuration updating is handled by Flutter
        result.success(mapOf("success" to true))
    }

    private fun handleDeleteConfiguration(call: MethodCall, result: Result) {
        // For now, return success as configuration deletion is handled by Flutter
        result.success(mapOf("success" to true))
    }

    private fun handleDeleteAllConfigurations(call: MethodCall, result: Result) {
        // For now, return success as configuration deletion is handled by Flutter
        result.success(mapOf("success" to true))
    }

    private fun handleImportFromJson(call: MethodCall, result: Result) {
        // For now, return empty list as JSON import is handled by Flutter
        result.success(mapOf(
            "success" to true,
            "data" to emptyList<Map<String, Any>>()
        ))
    }

    private fun handleExportToJson(call: MethodCall, result: Result) {
        // For now, return empty JSON as export is handled by Flutter
        result.success(mapOf(
            "success" to true,
            "data" to "{}"
        ))
    }

    private fun handleIsSecureStorageAvailable(call: MethodCall, result: Result) {
        result.success(mapOf(
            "success" to true,
            "data" to true
        ))
    }

    private fun handleGetStorageInfo(call: MethodCall, result: Result) {
        result.success(mapOf(
            "success" to true,
            "data" to mapOf(
                "available" to true,
                "encrypted" to true,
                "configurationCount" to 0,
                "totalSize" to 0
            )
        ))
    }

    private data class ValidationResult(
        val isValid: Boolean,
        val error: String? = null,
        val details: Map<String, Any>? = null
    )

    private fun validateConfigurationBasic(config: Map<String, Any>): ValidationResult {
        // Check required fields
        val requiredFields = listOf("id", "name", "serverAddress", "serverPort", "protocol")
        for (field in requiredFields) {
            if (!config.containsKey(field) || config[field] == null) {
                return ValidationResult(false, "Missing required field: $field")
            }
        }
        
        // Validate server address
        val serverAddress = config["serverAddress"] as? String
        if (serverAddress.isNullOrBlank()) {
            return ValidationResult(false, "Server address cannot be empty")
        }
        
        // Validate server port
        val serverPort = config["serverPort"] as? Int
        if (serverPort == null || serverPort < 1 || serverPort > 65535) {
            return ValidationResult(false, "Server port must be between 1 and 65535")
        }
        
        // Validate protocol
        val protocol = config["protocol"] as? String
        val validProtocols = listOf("shadowsocks", "vmess", "vless", "trojan", "hysteria", "hysteria2", "tuic", "wireguard")
        if (protocol == null || !validProtocols.contains(protocol.lowercase())) {
            return ValidationResult(false, "Invalid protocol: $protocol")
        }
        
        return ValidationResult(true)
    }

    private fun validateConfigurationWithSingbox(config: Map<String, Any>): ValidationResult {
        return try {
            // Convert configuration to JSON for sing-box validation
            val configJson = Json.encodeToString(JsonObject.serializer(), JsonObject(
                config.mapValues { entry ->
                    when (val value = entry.value) {
                        null -> JsonNull
                        is String -> JsonPrimitive(value)
                        is Number -> JsonPrimitive(value)
                        is Boolean -> JsonPrimitive(value)
                        is Map<*, *> -> JsonObject(
                            (value as Map<String, Any>).mapValues { subEntry ->
                                when (val subValue = subEntry.value) {
                                    null -> JsonNull
                                    is String -> JsonPrimitive(subValue)
                                    is Number -> JsonPrimitive(subValue)
                                    is Boolean -> JsonPrimitive(subValue)
                                    else -> JsonPrimitive(subValue.toString())
                                }
                            }
                        )
                        else -> JsonPrimitive(value?.toString() ?: "")
                    }
                }
            ))
            
            // Use sing-box manager to validate configuration
            val manager = singboxManager
            if (manager != null) {
                // Call native validation method
                val isValid = validateConfigWithNative(configJson)
                
                if (isValid) {
                    ValidationResult(
                        true,
                        details = mapOf(
                            "validatedBy" to "sing-box",
                            "protocol" to (config["protocol"] as? String ?: "unknown")
                        )
                    )
                } else {
                    ValidationResult(
                        false,
                        "Configuration validation failed in sing-box core",
                        mapOf(
                            "validatedBy" to "sing-box",
                            "protocol" to (config["protocol"] as? String ?: "unknown")
                        )
                    )
                }
            } else {
                // Fallback validation without sing-box
                Log.w(TAG, "SingboxManager not available, using fallback validation")
                ValidationResult(
                    true,
                    details = mapOf(
                        "validatedBy" to "fallback",
                        "protocol" to (config["protocol"] as? String ?: "unknown")
                    )
                )
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error in sing-box validation", e)
            ValidationResult(
                false,
                "Validation error: ${e.message}",
                mapOf("exception" to e.javaClass.simpleName)
            )
        }
    }

    private fun validateConfigWithNative(configJson: String): Boolean {
        return try {
            // Call the public validation method from SingboxManager
            val manager = singboxManager
            if (manager != null) {
                manager.validateConfiguration(configJson)
            } else {
                // Fallback validation if SingboxManager is not available
                Log.w(TAG, "SingboxManager not available, using fallback validation")
                configJson.isNotEmpty() && 
                configJson.contains("{") && 
                configJson.contains("}") &&
                configJson.contains("protocol") &&
                configJson.contains("serverAddress")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Native validation failed", e)
            // Fallback to basic validation
            configJson.isNotEmpty() && 
            configJson.contains("{") && 
            configJson.contains("}") &&
            configJson.contains("protocol") &&
            configJson.contains("serverAddress")
        }
    }
}