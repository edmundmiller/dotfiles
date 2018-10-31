export GRADLE_USER_HOME="$XDG_CACHE_HOME/gradle"
export JAVA_HOME="/usr/lib/jvm/open-jdk"

# Android
export ANDROID_SDK_HOME="$XDG_DATA_HOME/android"
export ADB_VENDOR_KEYS="$ANDROID_SDK_HOME/.android"
path=( $ANDROID_SDK_HOME/bin $path )
