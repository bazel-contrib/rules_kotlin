#include <jni.h>

extern "C" JNIEXPORT jstring JNICALL
Java_native_1lib_NativeLib_greeting(JNIEnv *env, jclass) {
    return env->NewStringUTF("Hello from native!");
}
