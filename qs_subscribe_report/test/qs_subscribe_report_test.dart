import 'package:flutter_test/flutter_test.dart';
import 'package:qs_subscribe_report/qs_subscribe_report.dart';
import 'package:qs_subscribe_report/qs_subscribe_report_platform_interface.dart';
import 'package:qs_subscribe_report/qs_subscribe_report_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockQsSubscribeReportPlatform
    with MockPlatformInterfaceMixin
    implements QsSubscribeReportPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final QsSubscribeReportPlatform initialPlatform = QsSubscribeReportPlatform.instance;

  test('$MethodChannelQsSubscribeReport is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelQsSubscribeReport>());
  });

  test('getPlatformVersion', () async {
    QsSubscribeReport qsSubscribeReportPlugin = QsSubscribeReport();
    MockQsSubscribeReportPlatform fakePlatform = MockQsSubscribeReportPlatform();
    QsSubscribeReportPlatform.instance = fakePlatform;

    expect(await qsSubscribeReportPlugin.getPlatformVersion(), '42');
  });
}
