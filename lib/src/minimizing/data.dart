// Dart imports:
import 'dart:core';

// Flutter imports:
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// Package imports:
import 'package:zego_uikit/zego_uikit.dart';

// Project imports:
import 'package:zego_uikit_prebuilt_call/src/config.dart';
import 'package:zego_uikit_prebuilt_call/src/events.dart';

// Project imports:

/// @nodoc
class ZegoCallMinimizeData {
  const ZegoCallMinimizeData( {
    required this.appID,
    required this.appSign,
    required this.callID,
    required this.userID,
    required this.userName,
    required this.isCalling,
    required this.callWidget,
    required this.config,
    required this.events,
    required this.isPrebuiltFromMinimizing,
    required this.plugins,
    this.durationStartTime,
    this.onDispose,
  });

  /// you need to fill in the appID you obtained from console.zegocloud.com
  final int appID;

  final Widget callWidget;
  /// You can customize the callID arbitrarily,
  /// just need to know: users who use the same callID can talk with each other.
  final String callID;

  /// for Android/iOS
  /// you need to fill in the appID you obtained from console.zegocloud.com
  final String appSign;

  /// local user info
  final String userID;
  final String userName;
  final bool isCalling;
  final ZegoUIKitPrebuiltCallConfig config;
  final ZegoUIKitPrebuiltCallEvents events;

  final VoidCallback? onDispose;

  final bool isPrebuiltFromMinimizing;

  /// call duration
  final DateTime? durationStartTime;

  final List<IZegoUIKitPlugin>? plugins;
  @override
  String toString() {
    return 'app id:$appID, app sign:$appSign, call id:$callID, '
        'isPrebuiltFromMinimizing: $isPrebuiltFromMinimizing, '
        'user id:$userID, user name:$userName, '
        'duration start time:$durationStartTime, '
        'config:$config ';
  }
}
