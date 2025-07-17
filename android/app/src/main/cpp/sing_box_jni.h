#ifndef SING_BOX_JNI_H
#define SING_BOX_JNI_H

#include <jni.h>

#ifdef __cplusplus
extern "C" {
#endif

// JNI method declarations for SingboxManager
JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeInit(JNIEnv *env, jobject thiz);

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeStart(JNIEnv *env, jobject thiz, 
                                                        jstring config, jint tun_fd);

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeStop(JNIEnv *env, jobject thiz);

JNIEXPORT jstring JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeGetStats(JNIEnv *env, jobject thiz);

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeIsRunning(JNIEnv *env, jobject thiz);

JNIEXPORT void JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeCleanup(JNIEnv *env, jobject thiz);

JNIEXPORT jstring JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeGetLastError(JNIEnv *env, jobject thiz);

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeValidateConfig(JNIEnv *env, jobject thiz, jstring config);

JNIEXPORT jstring JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeGetVersion(JNIEnv *env, jobject thiz);

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeSetLogLevel(JNIEnv *env, jobject thiz, jint level);

JNIEXPORT jstring JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeGetLogs(JNIEnv *env, jobject thiz);

JNIEXPORT jstring JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeGetMemoryUsage(JNIEnv *env, jobject thiz);

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeOptimizePerformance(JNIEnv *env, jobject thiz);

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeHandleNetworkChange(JNIEnv *env, jobject thiz, jstring networkInfo);

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeUpdateConfiguration(JNIEnv *env, jobject thiz, jstring config);

JNIEXPORT jstring JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeGetConnectionInfo(JNIEnv *env, jobject thiz);

JNIEXPORT jstring JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeGetDetailedStats(JNIEnv *env, jobject thiz);

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeResetStats(JNIEnv *env, jobject thiz);

JNIEXPORT jboolean JNICALL
Java_com_tunnelmax_vpnclient_SingboxManager_nativeSetStatsCallback(JNIEnv *env, jobject thiz, jlong callback);

#ifdef __cplusplus
}
#endif

#endif // SING_BOX_JNI_H