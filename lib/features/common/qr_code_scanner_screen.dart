import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class QRCodeScannerScreen extends StatefulHookConsumerWidget {
  const QRCodeScannerScreen({super.key});

  Future<String?> open(BuildContext context) async {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => const QRCodeScannerScreen(),
      ),
    );
  }

  @override
  ConsumerState<QRCodeScannerScreen> createState() =>
      _QRCodeScannerScreenState();
}

class _QRCodeScannerScreenState extends ConsumerState<QRCodeScannerScreen>
    with WidgetsBindingObserver, PresLogger {
  final MobileScannerController controller = MobileScannerController(
    detectionTimeoutMs: 500,
    autoStart: false,
  );
  bool started = false;

  // late FlutterEasyPermission _easyPermission;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScanner();

    // _easyPermission = FlutterEasyPermission()
    //   ..addPermissionCallback(onGranted: (requestCode, androidPerms, iosPerm) {
    //     debugPrint("android:$androidPerms");
    //     debugPrint("iOS:$iosPerm");
    //     startQrScannerIfPermissionGranted();
    //   }, onDenied: (requestCode, androidPerms, iosPerm, isPermanent) {
    //     if (isPermanent) {
    //       FlutterEasyPermission.showAppSettingsDialog(title: "Camera");
    //     } else {
    //       debugPrint("android:$androidPerms");
    //       debugPrint("iOS:$iosPerm");
    //     }
    //   }, onSettingsReturned: () {
    //     startQrScannerIfPermissionGranted();
    //   });
  }

  Future<bool> _requestCameraPermission() async {
    final hasPermission = await Permission.camera.status.isGranted;

    if (hasPermission) return true;

    return await Permission.camera.request().isGranted;
  }

  Future<void> _initializeScanner() async {
    final hasPermission = await _requestCameraPermission();
    if (hasPermission) {
      _startScanner();
    } else {
      _showPermissionDialog();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    // _easyPermission.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    /// Checking app cycle so that when user returns from settings, need to recheck for permissions
    if (state == AppLifecycleState.resumed) {
      _checkPermissionAndStartScanner();
    }
  }

  Future<void> _checkPermissionAndStartScanner() async {
    if (await Permission.camera.status.isGranted ||
        await Permission.camera.request().isGranted) {
      _startScanner();
    } else {
      setState(() {}); // Trigger rebuild to show permission denied UI
    }
  }

  Future<void> _startScanner() async {
    loggy.info("Starting scanner");
    await controller.stop();
    await controller.start().whenComplete(() {
      setState(() {
        started = true;
      });
    }).catchError((error) {
      loggy.warning("Error starting scanner: $error");
    });
  }

  Future<void> startQrScannerIfPermissionIsGranted() async {
    if (await Permission.camera.status.isGranted ||
        await Permission.camera.request().isGranted) {
      _startScanner();
    }
  }

  // void startQrScannerIfPermissionGranted() {
  //   FlutterEasyPermission.has(perms: permissions, permsGroup: permissionGroup).then((value) {
  //     if (value) {
  //       controller.start().then((result) {
  //         if (result != null) {
  //           setState(() {
  //             started = true;
  //           });
  //         }
  //       }).catchError((error) {
  //         loggy.warning("Error starting scanner: $error");
  //       });
  //     } else {}
  //   });
  // }

  void _showPermissionDialog() {}

  @override
  Widget build(BuildContext context) {
    final Translations t = ref.watch(translationsProvider);

    return FutureBuilder(
      future: Permission.camera.status.isGranted,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data == true) {
          return _buildScannerUI(context, t);
        } else {
          return _buildPermissionDeniedUI(context, t);
        }
      },
    );
  }

  Widget _buildScannerUI(BuildContext context, Translations t) {
    final size = MediaQuery.sizeOf(context);
    final overlaySize = (size.shortestSide - 12).coerceAtMost(248);
    // _startScanner();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: Theme.of(context).iconTheme.copyWith(
              color: Colors.white,
              size: 32,
            ),
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.flash_24_regular),
            tooltip: t.profile.add.qrScanner.torchSemanticLabel,
            onPressed: () => controller.toggleTorch(),
          ),
          // IconButton(
          //   icon: ValueListenableBuilder(
          //     valueListenable: controller.torchState,
          //     builder: (context, state, child) {
          //       switch (state) {
          //         case TorchState.off:
          //           return const Icon(
          //             FluentIcons.flash_off_24_regular,
          //             color: Colors.grey,
          //           );
          //         case TorchState.on:
          //           return const Icon(
          //             FluentIcons.flash_24_regular,
          //             color: Colors.yellow,
          //           );
          //       }
          //     },
          //   ),
          //   tooltip: t.profile.add.qrScanner.torchSemanticLabel,
          //   onPressed: () => controller.toggleTorch(),
          // ),
          IconButton(
            icon: const Icon(FluentIcons.camera_switch_24_regular),
            tooltip: t.profile.add.qrScanner.facingSemanticLabel,
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final rawData = capture.barcodes.first.rawValue;
              loggy.debug('captured raw: [$rawData]');
              if (rawData != null) {
                final uri = Uri.tryParse(rawData);
                if (context.mounted && uri != null) {
                  loggy.debug('captured url: [$uri]');
                  Navigator.of(context, rootNavigator: true)
                      .pop(uri.toString());
                }
              } else {
                loggy.warning("unable to capture");
              }
            },
            errorBuilder: (_, error, __) {
              final message = switch (error.errorCode) {
                MobileScannerErrorCode.permissionDenied =>
                  t.profile.add.qrScanner.permissionDeniedError,
                _ => t.profile.add.qrScanner.unexpectedError,
              };

              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Icon(
                        FluentIcons.error_circle_24_regular,
                        color: Colors.white,
                      ),
                    ),
                    Text(message),
                    Text(error.errorDetails?.message ?? ''),
                  ],
                ),
              );
            },
          ),
          if (started)
            CustomPaint(
              painter: ScannerOverlay(
                Rect.fromCenter(
                  center: size.center(Offset.zero),
                  width: overlaySize,
                  height: overlaySize,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedUI(BuildContext context, Translations t) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: Theme.of(context).iconTheme.copyWith(
              color: Colors.white,
              size: 32,
            ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(t.profile.add.qrScanner.permissionDeniedError),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showPermissionDialog,
              child: const Text("Settings"),
            ),
          ],
        ),
      ),
    );
  }
}

class ScannerOverlay extends CustomPainter {
  ScannerOverlay(this.scanWindow);

  final Rect scanWindow;
  final double borderRadius = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.largest);
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          scanWindow,
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
      );

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final backgroundWithCutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final borderRect = RRect.fromRectAndCorners(
      scanWindow,
      topLeft: Radius.circular(borderRadius),
      topRight: Radius.circular(borderRadius),
      bottomLeft: Radius.circular(borderRadius),
      bottomRight: Radius.circular(borderRadius),
    );

    canvas.drawPath(backgroundWithCutout, backgroundPaint);
    canvas.drawRRect(borderRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
