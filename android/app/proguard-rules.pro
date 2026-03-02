-keep class org.videolan.libvlc.** { *; }
-keep class org.videolan.vlc.** { *; }

-keep class org.videolan.libvlc.interfaces.IMedia$Track { *; }

-dontwarn org.videolan.libvlc.**
-dontwarn org.videolan.vlc.**
