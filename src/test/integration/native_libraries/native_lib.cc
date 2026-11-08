#include <jni.h>

extern "C" JNIEXPORT jint JNICALL Java_nativelib_NativeLib_answer(JNIEnv*, jclass) {
  return 42;
}
