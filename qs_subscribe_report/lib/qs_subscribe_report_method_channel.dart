import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'qs_subscribe_report_platform_interface.dart';

/// An implementation of [QsSubscribeReportPlatform] that uses method channels.
class MethodChannelQsSubscribeReport extends QsSubscribeReportPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('qs_subscribe_report');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
