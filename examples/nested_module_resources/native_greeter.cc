#include <jni.h>

extern "C" JNIEXPORT jstring JNICALL
Java_NativeGreeter_greetFromNative(JNIEnv *env, jclass) {
    return env->NewStringUTF("Hello from native!");
}
