package com.ebic.user.ebic_user

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by the `health`
// plugin on Android 14+: it uses registerForActivityResult to request Health
// Connect permissions, which needs an Activity castable to ComponentActivity.
class MainActivity : FlutterFragmentActivity()
