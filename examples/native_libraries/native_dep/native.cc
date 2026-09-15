#include <jni.h>

extern "C" JNIEXPORT jint JNICALL Java_Native_answer(JNIEnv *, jclass) {
  return 42;
}
