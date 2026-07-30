import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'qs_subscribe_report_method_channel.dart';

abstract class QsSubscribeReportPlatform extends PlatformInterface {
  /// Constructs a QsSubscribeReportPlatform.
  QsSubscribeReportPlatform() : super(token: _token);

  static final Object _token = Object();

  static QsSubscribeReportPlatform _instance = MethodChannelQsSubscribeReport();

  /// The default instance of [QsSubscribeReportPlatform] to use.
  ///
  /// Defaults to [MethodChannelQsSubscribeReport].
  static QsSubscribeReportPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [QsSubscribeReportPlatform] when
  /// they register themselves.
  static set instance(QsSubscribeReportPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
