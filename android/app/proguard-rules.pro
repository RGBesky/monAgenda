# Flutter-specific ProGuard rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep SQLCipher
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# Keep flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep flutter_local_notifications
-keep class com.dexterous.** { *; }

# Keep home_widget
-keep class es.antonborri.home_widget.** { *; }

# Keep workmanager
-keep class be.tramckrijte.workmanager.** { *; }

# Keep mobile_scanner
-keep class dev.steenbakker.mobile_scanner.** { *; }

# Prevent stripping of Gson (used by some plugins)
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
