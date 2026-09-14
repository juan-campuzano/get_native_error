#include "gne_signal.h"

#include <jni.h>
#include <stdlib.h>
#include <string.h>

static void gne_install_jni(JNIEnv *env, jobject thiz, jstring path) {
  (void)thiz;
  if (path == NULL) {
    return;
  }
  const char *chars = (*env)->GetStringUTFChars(env, path, NULL);
  if (chars == NULL) {
    return;
  }
  gne_install(chars, "android");
  (*env)->ReleaseStringUTFChars(env, path, chars);
}

static void gne_crash_jni(JNIEnv *env, jobject thiz) {
  (void)env;
  (void)thiz;
  gne_crash_native();
}

JNIEXPORT jint JNI_OnLoad(JavaVM *vm, void *reserved) {
  (void)reserved;
  JNIEnv *env = NULL;
  if ((*vm)->GetEnv(vm, (void **)&env, JNI_VERSION_1_6) != JNI_OK || env == NULL) {
    return JNI_ERR;
  }
  jclass cls =
      (*env)->FindClass(env, "com/getnativeerror/get_native_error/GetNativeErrorPlugin");
  if (cls == NULL) {
    return JNI_ERR;
  }
  JNINativeMethod methods[] = {
      {"nativeInstall", "(Ljava/lang/String;)V", (void *)gne_install_jni},
      {"nativeCrash", "()V", (void *)gne_crash_jni},
  };
  if ((*env)->RegisterNatives(env, cls, methods, 2) != 0) {
    return JNI_ERR;
  }
  return JNI_VERSION_1_6;
}
