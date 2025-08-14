# flutter_stripe
-keep class com.stripe.** { *; }
-dontwarn com.stripe.**

# The error log also mentioned reactnativestripesdk, so let's add rules for it too.
-keep class com.reactnativestripesdk.** { *; }
-dontwarn com.reactnativestripesdk.**