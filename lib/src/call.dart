// Dart imports:
import 'dart:async';
import 'dart:core';

// Flutter imports:
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Package imports:
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_uikit/zego_uikit.dart';

// Project imports:
import 'package:zego_uikit_prebuilt_call/src/components/components.dart';
import 'package:zego_uikit_prebuilt_call/src/components/duration_time_board.dart';
import 'package:zego_uikit_prebuilt_call/src/components/pop_up_manager.dart';
import 'package:zego_uikit_prebuilt_call/src/config.dart';
import 'package:zego_uikit_prebuilt_call/src/controller.dart';
import 'package:zego_uikit_prebuilt_call/src/events.dart';
import 'package:zego_uikit_prebuilt_call/src/events.defines.dart';
import 'package:zego_uikit_prebuilt_call/src/internal/events.dart';
import 'package:zego_uikit_prebuilt_call/src/invitation/callkit/background_service.dart';
import 'package:zego_uikit_prebuilt_call/src/minimizing/data.dart';
import 'package:zego_uikit_prebuilt_call/src/minimizing/defines.dart';
import 'package:zego_uikit_prebuilt_call/src/minimizing/overlay_machine.dart';

/// Call Widget.
/// You can embed this widget into any page of your project to integrate the functionality of a call.
/// You can refer to our [documentation](https://docs.zegocloud.com/article/14826),
/// or our [sample code](https://github.com/ZEGOCLOUD/zego_uikit_prebuilt_call_example_flutter).
///
/// If you need the function of `call invitation`, please use [ZegoUIKitPrebuiltCallInvitationService] together.
/// And refer to the [sample code](https://github.com/ZEGOCLOUD/zego_uikit_prebuilt_call_example_flutter/tree/master/call_with_offline_invitation).
///
/// {@category APIs}
/// {@category Events}
/// {@category Configs}
/// {@category Migration_v4.x}
class ZegoUIKitPrebuiltCall extends StatefulWidget {
  const ZegoUIKitPrebuiltCall({
    Key? key,
    required this.appID,
    required this.appSign,
    required this.callID,
    required this.userID,
    required this.userName,
    required this.config,
    required this.isCalling,
    required this.callWidget,
    this.events,
    this.onDispose,
    this.plugins,
  }) : super(key: key);

  /// You can create a project and obtain an appID from the [ZEGOCLOUD Admin Console](https://console.zegocloud.com).
  final int appID;

  /// You can create a project and obtain an appSign from the [ZEGOCLOUD Admin Console](https://console.zegocloud.com).
  final String appSign;

  /// The ID of the currently logged-in user.
  /// It can be any valid string.
  /// Typically, you would use the ID from your own user system, such as Firebase.
  final String userID;

  final bool isCalling;
  final Widget callWidget;

  /// The name of the currently logged-in user.
  /// It can be any valid string.
  /// Typically, you would use the name from your own user system, such as Firebase.
  final String userName;

  /// The ID of the call.
  /// This ID is a unique identifier for the current call, so you need to ensure its uniqueness.
  /// It can be any valid string.
  /// Users who provide the same callID will be logged into the same room for the call.
  final String callID;
  /// Initialize the configuration for the call.
  final ZegoUIKitPrebuiltCallConfig config;

  /// Initialize the events for the call.
  final ZegoUIKitPrebuiltCallEvents? events;

  /// Callback when the page is destroyed.
  final VoidCallback? onDispose;

  final List<IZegoUIKitPlugin>? plugins;

  @override
  State<ZegoUIKitPrebuiltCall> createState() => _ZegoUIKitPrebuiltCallState();
}

class _ZegoUIKitPrebuiltCallState extends State<ZegoUIKitPrebuiltCall>
    with SingleTickerProviderStateMixin {
  var barVisibilityNotifier = ValueNotifier<bool>(true);
  var barRestartHideTimerNotifier = ValueNotifier<int>(0);
  var chatViewVisibleNotifier = ValueNotifier<bool>(false);

  List<StreamSubscription<dynamic>?> subscriptions = [];
  ZegoCallEventListener? _eventListener;

  late ZegoCallMinimizeData minimizeData;

  Timer? durationTimer;
  DateTime? durationStartTime;
  var durationNotifier = ValueNotifier<Duration>(Duration.zero);

  final popUpManager = ZegoCallPopUpManager();

  Map<String, bool> requiredUsersEnteredStatus = {};

  ZegoUIKitPrebuiltCallEvents get events =>
      widget.events ?? ZegoUIKitPrebuiltCallEvents();

  ZegoUIKitPrebuiltCallController get controller =>
      ZegoUIKitPrebuiltCallController();

  bool get isRequiredUserAllEntered {
    bool isAllEntered = true;
    requiredUsersEnteredStatus.forEach((userID, isEntered) {
      isAllEntered = isAllEntered && isEntered;
    });

    return isAllEntered;
  }

  @override
  void initState() {
    super.initState();

    ZegoUIKit().getZegoUIKitVersion().then((version) {
      ZegoLoggerService.logInfo(
        'version: zego_uikit_prebuilt_call:4.11.6; $version, \n'
        'config:${widget.config}, \n'
        'events:${widget.events}, \n',
        tag: 'call',
        subTag: 'prebuilt',
      );
    });

    ZegoLoggerService.logInfo(
      'mini machine state is ${ZegoCallMiniOverlayMachine().state()}',
      tag: 'call',
      subTag: 'prebuilt',
    );

    _eventListener = ZegoCallEventListener(widget.events);
    _eventListener?.init();

    final isPrebuiltFromMinimizing = ZegoCallMiniOverlayPageState.idle !=
        ZegoCallMiniOverlayMachine().state();

    initDurationTimer(
      isPrebuiltFromMinimizing: isPrebuiltFromMinimizing,
    );

    correctConfigValue();

    minimizeData = ZegoCallMinimizeData(
      appID: widget.appID,
      appSign: widget.appSign,
      callID: widget.callID,
      userID: widget.userID,
      userName: widget.userName,
      config: widget.config,
      events: events,
      plugins: widget.plugins,
      onDispose: widget.onDispose,
      isPrebuiltFromMinimizing: isPrebuiltFromMinimizing,
      durationStartTime: durationStartTime,
      isCalling: widget.isCalling, callWidget: widget.callWidget
    );

    if (isPrebuiltFromMinimizing) {
      ZegoLoggerService.logInfo(
        'mini machine state is not idle, context will not be init',
        tag: 'call',
        subTag: 'prebuilt',
      );
    } else {
      controller.private.initByPrebuilt(
        prebuiltConfig: widget.config,
        popUpManager: popUpManager,
        events: events,
      );
      controller.user.private.initByPrebuilt(config: widget.config);
      controller.audioVideo.private.initByPrebuilt(
        config: widget.config,
        events: widget.events,
      );
      controller.minimize.private.initByPrebuilt(
        minimizeData: minimizeData,
      );

      /// not wake from mini page
      initContext();
    }
    ZegoCallMiniOverlayMachine().changeState(ZegoCallMiniOverlayPageState.idle);

    subscriptions
      ..add(
        ZegoUIKit().getMeRemovedFromRoomStream().listen(onMeRemovedFromRoom),
      )
      ..add(ZegoUIKit().getErrorStream().listen(onUIKitError))
      ..add(ZegoUIKit().getUserLeaveStream().listen(onUserLeave));

    checkRequiredParticipant();
  }

  @override
  void dispose() {
    super.dispose();

    _eventListener?.uninit();

    for (final subscription in subscriptions) {
      subscription?.cancel();
    }

    widget.onDispose?.call();

    durationTimer?.cancel();

    if (ZegoCallMiniOverlayPageState.minimizing !=
        ZegoCallMiniOverlayMachine().state()) {
      controller.private.uninitByPrebuilt();
      controller.user.private.uninitByPrebuilt();
      controller.audioVideo.private.uninitByPrebuilt();
      controller.minimize.private.uninitByPrebuilt();

      ZegoUIKit().leaveRoom();
      // await ZegoUIKit().uninit();
    } else {
      ZegoLoggerService.logInfo(
        'mini machine state is minimizing, room will not be leave',
        tag: 'call',
        subTag: 'prebuilt',
      );
    }

    if (ZegoPluginAdapter().getPlugin(ZegoUIKitPluginType.beauty) != null) {
      ZegoUIKit().getBeautyPlugin().uninit();
    }

    ZegoCallKitBackgroundService().setWaitCallPageDisposeFlag(false);
  }

  void checkRequiredParticipant() {
    if (!widget.config.user.requiredUsers.enabled) {
      ZegoLoggerService.logInfo(
        'requiredUsers not enabled',
        tag: 'call',
        subTag: 'prebuilt',
      );

      return;
    }

    var isChecking = true;
    if (kDebugMode) {
      isChecking = widget.config.user.requiredUsers.detectInDebugMode;
    }
    if (isChecking) {
      updateRequiredUsersEnteredStatus();
      if (!isRequiredUserAllEntered) {
        Timer(
          Duration(
            seconds: widget.config.user.requiredUsers.detectSeconds,
          ),
          hangUpIfRequiredUsersNotAllEntered,
        );
      }
    } else {
      ZegoLoggerService.logInfo(
        'requiredUsers not need checking, '
        'kDebugMode:$kDebugMode, '
        'detectInDebugMode:${widget.config.user.requiredUsers.detectInDebugMode}',
        tag: 'call',
        subTag: 'prebuilt',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: WillPopScope(
        onWillPop: () async {
          /// not support end by return button
          return false;
        },
        child: ZegoScreenUtilInit(
          designSize: const Size(750, 1334),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            return widget.isCalling == true
                ? widget.callWidget
                : ZegoInputBoardWrapper(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return clickListener(
                          child: Stack(
                            children: [
                              background(constraints.maxWidth),
                              audioVideoContainer(
                                context,
                                constraints.maxWidth,
                                constraints.maxHeight,
                              ),
                              durationTimeBoard(),
                              if (widget.config.topMenuBar.isVisible)
                                topMenuBar()
                              else
                                Container(),
                              if (widget.config.bottomMenuBar.isVisible)
                                bottomMenuBar()
                              else
                                Container(),
                              foreground(context, constraints.maxHeight),
                            ],
                          ),
                        );
                      },
                    ),
                  );
          },
        ),
      ),
    );
  }

  void initDurationTimer({required bool isPrebuiltFromMinimizing}) {
    // if (!widget.config.duration.isVisible) {
    //   return;
    // }

    ZegoLoggerService.logInfo(
      'init duration',
      tag: 'call',
      subTag: 'prebuilt',
    );

    durationStartTime = isPrebuiltFromMinimizing
        ? ZegoCallMiniOverlayMachine().durationStartTime()
        : DateTime.now();
    durationNotifier.value = DateTime.now().difference(durationStartTime!);
    durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      durationNotifier.value = DateTime.now().difference(durationStartTime!);
      widget.config.duration.onDurationUpdate?.call(durationNotifier.value);
    });
  }

  Future<void> initPermissions() async {
    if (widget.config.turnOnCameraWhenJoining) {
      await requestPermission(Permission.camera);
    }
    if (widget.config.turnOnMicrophoneWhenJoining) {
      await requestPermission(Permission.microphone);
    }
  }

  Future<void> initContext() async {
    assert(widget.userID.isNotEmpty);
    assert(widget.userName.isNotEmpty);
    assert(widget.appID > 0);
    assert(widget.appSign.isNotEmpty);

    await initEffectsPlugins();

    final config = widget.config;
    initPermissions().then((value) async {
      ZegoUIKit().login(widget.userID, widget.userName);

      /// first set before create express
      await ZegoUIKit().setAdvanceConfigs(widget.config.advanceConfigs);

      ZegoUIKit()
          .init(appID: widget.appID, appSign: widget.appSign)
          .then((value) async {
        /// second set after create express
        await ZegoUIKit().setAdvanceConfigs(widget.config.advanceConfigs);

        _setVideoConfig();
        _setBeautyConfig();

        ZegoUIKit()

          /// maybe change back by button in calling, this call will reset to front
          // ..useFrontFacingCamera(true)
          ..updateVideoViewMode(
            config.audioVideoView.useVideoViewAspectFill,
          )
          ..enableVideoMirroring(config.audioVideoView.isVideoMirror)
          ..turnCameraOn(config.turnOnCameraWhenJoining)
          ..turnMicrophoneOn(config.turnOnMicrophoneWhenJoining)
          ..setAudioOutputToSpeaker(config.useSpeakerWhenJoining);

        ZegoUIKit().joinRoom(widget.callID).then((result) async {
          assert(result.errorCode == 0);

          if (result.errorCode != 0) {
            ZegoLoggerService.logError(
              'failed to login room:${result.errorCode},${result.extendedData}',
              tag: 'call',
              subTag: 'prebuilt',
            );
          }
        });
      });
    });
  }

  Future<void> _setVideoConfig() async {
    ZegoLoggerService.logInfo(
      'video config:${widget.config.video}',
      tag: 'call',
      subTag: 'prebuilt',
    );

    await ZegoUIKit().enableTrafficControl(
      true,
      [
        ZegoUIKitTrafficControlProperty.adaptiveResolution,
        ZegoUIKitTrafficControlProperty.adaptiveFPS,
      ],
      minimizeVideoConfig: ZegoUIKitVideoConfig.preset360P(),
      isFocusOnRemote: true,
      streamType: ZegoStreamType.main,
    );

    ZegoUIKit().setVideoConfig(
      widget.config.video,
    );
  }

  Future<void> _setBeautyConfig() async {
    if (ZegoPluginAdapter().getPlugin(ZegoUIKitPluginType.beauty) != null) {
      ZegoUIKit().enableCustomVideoProcessing(true);
    }
  }

  Future<void> initEffectsPlugins() async {
    if (widget.plugins != null) {
      ZegoUIKit().installPlugins(widget.plugins!);
    }

    if (ZegoPluginAdapter().getPlugin(ZegoUIKitPluginType.beauty) != null) {
      ZegoUIKit()
          .getBeautyPlugin()
          .setConfig(widget.config.beauty ?? ZegoBeautyPluginConfig());
      await ZegoUIKit()
          .getBeautyPlugin()
          .init(widget.appID, appSign: widget.appSign)
          .then((value) {
        ZegoLoggerService.logInfo(
          'effects plugin init done',
          tag: 'call',
          subTag: 'plugin',
        );
      });
    }
  }

  void correctConfigValue() {
    if (widget.config.bottomMenuBar.maxCount > 5) {
      widget.config.bottomMenuBar.maxCount = 5;
      ZegoLoggerService.logInfo(
        "menu bar buttons limited count's value  is exceeding the maximum limit",
        tag: 'call',
        subTag: 'prebuilt',
      );
    }
  }

  void onUserLeave(List<ZegoUIKitUser> users) {
    if (ZegoUIKit().getRemoteUsers().isNotEmpty) {
      return;
    }

    ZegoLoggerService.logInfo(
      'onUserLeave',
      tag: 'call',
      subTag: 'prebuilt',
    );

    //  remote users is empty
    final callEndEvent = ZegoCallEndEvent(
      callID: widget.callID,
      reason: ZegoCallEndReason.remoteHangUp,
      isFromMinimizing: ZegoCallMiniOverlayPageState.minimizing ==
          ZegoUIKitPrebuiltCallController().minimize.state,
    );
    defaultAction() {
      defaultEndAction(callEndEvent);
    }

    if (events.onCallEnd != null) {
      events.onCallEnd?.call(callEndEvent, defaultAction);
    } else {
      defaultAction.call();
    }
  }

  Widget clickListener({required Widget child}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        /// listen only click event in empty space
        if (widget.config.bottomMenuBar.hideByClick) {
          barVisibilityNotifier.value = !barVisibilityNotifier.value;
        }
      },
      child: Listener(
        ///  listen for all click events in current view, include the click
        ///  receivers(such as button...), but only listen
        onPointerDown: (e) {
          barRestartHideTimerNotifier.value =
              DateTime.now().millisecondsSinceEpoch;
        },
        child: AbsorbPointer(
          absorbing: false,
          child: child,
        ),
      ),
    );
  }

  Widget audioVideoContainer(
    BuildContext context,
    double preferWidth,
    double preferHeight,
  ) {
    audioVideoViewCreator(ZegoUIKitUser user) {
      return ZegoAudioVideoView(
        user: user,
        borderRadius: 18.0.zW,
        borderColor: Colors.transparent,
        backgroundBuilder: audioVideoViewBackground,
        foregroundBuilder: audioVideoViewForeground,
        avatarConfig: ZegoAvatarConfig(
          showInAudioMode: widget.config.audioVideoView.showAvatarInAudioMode,
          showSoundWavesInAudioMode:
              widget.config.audioVideoView.showSoundWavesInAudioMode,
          builder: widget.config.avatarBuilder,
        ),
      );
    }

    return Positioned.fromRect(
      rect: widget.config.audioVideoView.containerRect?.call() ??
          Rect.fromLTWH(0, 0, preferWidth, preferHeight),
      child: widget.config.audioVideoView.containerBuilder != null
          ? StreamBuilder<List<ZegoUIKitUser>>(
              stream: ZegoUIKit().getUserListStream(),
              builder: (context, snapshot) {
                final allUsers = ZegoUIKit().getAllUsers();
                return StreamBuilder<List<ZegoUIKitUser>>(
                  stream: ZegoUIKit().getAudioVideoListStream(),
                  builder: (context, snapshot) {
                    return widget.config.audioVideoView.containerBuilder!.call(
                          context,
                          allUsers,
                          ZegoUIKit().getAudioVideoList(),
                          audioVideoViewCreator,
                        ) ??
                        defaultAudioVideoContainer();
                  },
                );
              },
            )
          : defaultAudioVideoContainer(),
    );
  }

  Widget defaultAudioVideoContainer() {
    /// audio video container
    if (widget.config.layout is ZegoLayoutPictureInPictureConfig) {
      final layout = (widget.config.layout as ZegoLayoutPictureInPictureConfig)
        ..smallViewSize ??= Size(190.0.zW, 338.0.zH)
        ..margin ??= EdgeInsets.only(
          left: 20.zR,
          top: 50.zR,
          right: 20.zR,
          bottom: 30.zR,
        );
      widget.config.layout = layout;
    }

    return ZegoAudioVideoContainer(
      layout: widget.config.layout,
      sources: const [
        ZegoAudioVideoContainerSource.user,
        ZegoAudioVideoContainerSource.audioVideo,
        ZegoAudioVideoContainerSource.screenSharing,
      ],
      backgroundBuilder: audioVideoViewBackground,
      foregroundBuilder: audioVideoViewForeground,
      screenSharingViewController: controller.screenSharing.viewController,
      avatarConfig: ZegoAvatarConfig(
        showInAudioMode: widget.config.audioVideoView.showAvatarInAudioMode,
        showSoundWavesInAudioMode:
            widget.config.audioVideoView.showSoundWavesInAudioMode,
        builder: widget.config.avatarBuilder,
      ),
      sortAudioVideo: (List<ZegoUIKitUser> users) {
        if (widget.config.layout is ZegoLayoutPictureInPictureConfig) {
          if (users.length > 1) {
            if (users.first.id == ZegoUIKit().getLocalUser().id) {
              /// local display small view
              users
                ..removeAt(0)
                ..insert(1, ZegoUIKit().getLocalUser());
            }
          }
        } else {
          final localUserIndex = users
              .indexWhere((user) => user.id == ZegoUIKit().getLocalUser().id);
          if (-1 != localUserIndex) {
            users.removeAt(localUserIndex);
            users = [
              ZegoUIKit().getLocalUser(),
              ...List<ZegoUIKitUser>.from(users.reversed)
            ];
          }
        }
        return users;
      },
    );
  }

  Widget topMenuBar() {
    final isLightStyle =
        ZegoCallMenuBarStyle.light == widget.config.topMenuBar.style;
    final safeAreaInsets = MediaQuery.of(context).padding;

    return Positioned(
      left: 0,
      right: 0,
      top: safeAreaInsets.top,
      child: ZegoCallTopMenuBar(
        height: widget.config.topMenuBar.height ?? 80.zR,
        config: widget.config,
        events: events,
        defaultEndAction: defaultEndAction,
        defaultHangUpConfirmationAction: defaultHangUpConfirmationAction,
        visibilityNotifier: barVisibilityNotifier,
        minimizeData: minimizeData,
        restartHideTimerNotifier: barRestartHideTimerNotifier,
        isHangUpRequestingNotifier:
            controller.private.isHangUpRequestingNotifier,
        backgroundColor: widget.config.topMenuBar.backgroundColor ??
            (isLightStyle ? null : ZegoUIKitDefaultTheme.viewBackgroundColor),
        chatViewVisibleNotifier: chatViewVisibleNotifier,
        popUpManager: popUpManager,
      ),
    );
  }

  Widget bottomMenuBar() {
    final isLightStyle =
        ZegoCallMenuBarStyle.light == widget.config.bottomMenuBar.style;
    final safeAreaInsets = MediaQuery.of(context).padding;

    return Positioned(
      left: 0,
      right: 0,
      bottom:
          isLightStyle ? safeAreaInsets.bottom + 10.zR : safeAreaInsets.bottom,
      child: ZegoCallBottomMenuBar(
        buttonSize: Size(96.zR, 96.zR),
        config: widget.config,
        events: events,
        defaultEndAction: defaultEndAction,
        defaultHangUpConfirmationAction: defaultHangUpConfirmationAction,
        visibilityNotifier: barVisibilityNotifier,
        restartHideTimerNotifier: barRestartHideTimerNotifier,
        minimizeData: minimizeData,
        isHangUpRequestingNotifier:
            controller.private.isHangUpRequestingNotifier,
        height: widget.config.bottomMenuBar.height ??
            (isLightStyle ? null : 208.zR),
        backgroundColor: widget.config.bottomMenuBar.backgroundColor ??
            (isLightStyle ? null : ZegoUIKitDefaultTheme.viewBackgroundColor),
        borderRadius: isLightStyle ? null : 32.zR,
        chatViewVisibleNotifier: chatViewVisibleNotifier,
        popUpManager: popUpManager,
      ),
    );
  }

  Widget durationTimeBoard() {
    if (!widget.config.duration.isVisible) {
      return Container();
    }

    final safeAreaInsets = MediaQuery.of(context).padding;

    return Positioned(
      top: safeAreaInsets.top + 10.zR,
      left: 0,
      right: 0,
      child: ZegoCallDurationTimeBoard(
        durationNotifier: durationNotifier,
        fontSize: 25.zR,
      ),
    );
  }

  Widget audioVideoViewForeground(
    BuildContext context,
    Size size,
    ZegoUIKitUser? user,
    Map<String, dynamic> extraInfo,
  ) {
    if (extraInfo[ZegoViewBuilderMapExtraInfoKey.isScreenSharingView.name]
            as bool? ??
        false) {
      return Container();
    }

    return Stack(
      children: [
        widget.config.audioVideoView.foregroundBuilder
                ?.call(context, size, user, extraInfo) ??
            Container(color: Colors.transparent),
        ZegoCallAudioVideoForeground(
          size: size,
          user: user,
          showMicrophoneStateOnView:
              widget.config.audioVideoView.showMicrophoneStateOnView,
          showCameraStateOnView:
              widget.config.audioVideoView.showCameraStateOnView,
          showUserNameOnView: widget.config.audioVideoView.showUserNameOnView,
        ),
      ],
    );
  }

  Widget audioVideoViewBackground(
    BuildContext context,
    Size size,
    ZegoUIKitUser? user,
    Map<String, dynamic> extraInfo,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallView = (screenSize.width - size.width).abs() > 1;

    var backgroundColor =
        isSmallView ? const Color(0xff333437) : const Color(0xff4A4B4D);
    if (widget.config.layout is ZegoLayoutGalleryConfig) {
      backgroundColor = const Color(0xff4A4B4D);
    }

    return Stack(
      children: [
        Container(color: backgroundColor),
        widget.config.audioVideoView.backgroundBuilder
                ?.call(context, size, user, extraInfo) ??
            Container(color: Colors.transparent),
      ],
    );
  }

  Widget background(double maxWidth) {
    if (null != widget.config.background) {
      return widget.config.background!;
    }

    final screenSize = MediaQuery.of(context).size;
    final isSmallView = (screenSize.width - maxWidth).abs() > 1;

    var backgroundColor =
        isSmallView ? const Color(0xff333437) : const Color(0xff4A4B4D);
    if (widget.config.layout is ZegoLayoutGalleryConfig) {
      backgroundColor = const Color(0xff4A4B4D);
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(color: backgroundColor),
    );
  }

  Widget foreground(BuildContext context, double height) {
    return widget.config.foreground ?? Container();
  }

  void onMeRemovedFromRoom(String fromUserID) {
    ZegoLoggerService.logInfo(
      'local user removed by $fromUserID',
      tag: 'call',
      subTag: 'prebuilt',
    );

    ///more button, member list, chat dialog
    popUpManager.autoPop(context, widget.config.rootNavigator);

    final callEndEvent = ZegoCallEndEvent(
      callID: widget.callID,
      kickerUserID: fromUserID,
      reason: ZegoCallEndReason.kickOut,
      isFromMinimizing:
          ZegoCallMiniOverlayPageState.minimizing == controller.minimize.state,
    );
    defaultAction() {
      defaultEndAction(callEndEvent);
    }

    if (null != events.onCallEnd) {
      events.onCallEnd!.call(callEndEvent, defaultAction);
    } else {
      defaultAction.call();
    }
  }

  void onUIKitError(ZegoUIKitError error) {
    ZegoLoggerService.logError(
      'on uikit error:$error',
      tag: 'call',
      subTag: 'prebuilt',
    );

    events.onError?.call(error);
  }

  Future<bool> defaultHangUpConfirmationAction(
    ZegoCallHangUpConfirmationEvent event,
  ) async {
    if (widget.config.hangUpConfirmDialog.info == null) {
      return true;
    }

    final key = DateTime.now().millisecondsSinceEpoch;
    popUpManager.addAPopUpSheet(key);

    return showAlertDialog(
      event.context,
      widget.config.hangUpConfirmDialog.info!.title,
      widget.config.hangUpConfirmDialog.info!.message,
      [
        CupertinoDialogAction(
          child: Text(
            widget.config.hangUpConfirmDialog.info!.cancelButtonName,
            style: widget.config.hangUpConfirmDialog.actionTextStyle ??
                TextStyle(
                  fontSize: 26.zR,
                  color: const Color(0xff0055FF),
                ),
          ),
          onPressed: () {
            //  pop this dialog
            try {
              Navigator.of(
                context,
                rootNavigator: widget.config.rootNavigator,
              ).pop(false);
            } catch (e) {
              ZegoLoggerService.logError(
                'call hangup confirmation, '
                'navigator exception:$e, '
                'event:$event',
                tag: 'call',
                subTag: 'prebuilt',
              );
            }
          },
        ),
        CupertinoDialogAction(
          child: Text(
            widget.config.hangUpConfirmDialog.info!.confirmButtonName,
            style: TextStyle(fontSize: 26.zR, color: Colors.white),
          ),
          onPressed: () {
            //  pop this dialog
            try {
              Navigator.of(
                context,
                rootNavigator: widget.config.rootNavigator,
              ).pop(true);
            } catch (e) {
              ZegoLoggerService.logError(
                'call hangup confirmation, '
                'navigator exception:$e, '
                'event:$event',
                tag: 'call',
                subTag: 'prebuilt',
              );
            }
          },
        ),
      ],
      titleStyle: widget.config.hangUpConfirmDialog.titleStyle,
      contentStyle: widget.config.hangUpConfirmDialog.contentStyle,
      backgroundBrightness:
          widget.config.hangUpConfirmDialog.backgroundBrightness,
    ).then((result) {
      popUpManager.removeAPopUpSheet(key);

      return result;
    });
  }

  void defaultEndAction(
    ZegoCallEndEvent event,
  ) {
    ZegoLoggerService.logInfo(
      'default call end event, event:$event',
      tag: 'call',
      subTag: 'prebuilt',
    );

    if (ZegoCallMiniOverlayPageState.idle != controller.minimize.state) {
      /// now is minimizing state, not need to navigate, just switch to idle
      controller.minimize.hide();
    } else {
      try {
        Navigator.of(
          context,
          rootNavigator: widget.config.rootNavigator,
        ).pop(true);
      } catch (e) {
        ZegoLoggerService.logError(
          'call end, navigator exception:$e, event:$event',
          tag: 'call',
          subTag: 'prebuilt',
        );
      }
    }
  }

  void updateRequiredUsersEnteredStatus() {
    if (widget.config.user.requiredUsers.users.isEmpty) {
      return;
    }

    final remoteUsers = ZegoUIKit().getRemoteUsers();
    final requiredParticipants =
        List<ZegoUIKitUser>.from(widget.config.user.requiredUsers.users);
    for (var requiredParticipant in requiredParticipants) {
      final index =
          remoteUsers.indexWhere((user) => user.id == requiredParticipant.id);
      requiredUsersEnteredStatus[requiredParticipant.id] = -1 != index;
    }
  }

  void hangUpIfRequiredUsersNotAllEntered() {
    updateRequiredUsersEnteredStatus();

    if (!isRequiredUserAllEntered) {
      ZegoLoggerService.logWarn(
        'not all requiredUsers entered($requiredUsersEnteredStatus), call end.',
        tag: 'call',
        subTag: 'prebuilt',
      );

      ZegoUIKitPrebuiltCallController().hangUp(
        context,
        showConfirmation: false,
        reason: ZegoCallEndReason.abandoned,
      );
    } else {
      ZegoLoggerService.logInfo(
        'all requiredUsers entered($requiredUsersEnteredStatus)',
        tag: 'call',
        subTag: 'prebuilt',
      );
    }
  }
}
