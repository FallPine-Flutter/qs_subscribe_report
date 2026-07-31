import 'dart:async';
import 'dart:convert';

import 'package:ip_location/ip_location.dart';
import 'package:ip_location/ip_location_model.dart';
import 'package:qs_asa_attribution_info/qs_asa_attribution_info.dart';
import 'package:qs_aes_encrypt/qs_aes_encrypt.dart';
import 'package:qs_device_info/qs_device_info.dart';
import 'package:qs_log/qs_log.dart';
import 'package:qs_net_request/qs_net_request.dart';
import 'package:qs_storage_tool/qs_storage_tool.dart';

import 'failed_subscribtion_report.dart';

class QsSubscribeReport {
  static const String _failedReportsStorageKey =
      "qs_subscribe_report_failed_subscribtion_reports";
  static const int _maxRetryDelaySeconds = 60;

  static bool _isRetryLoopRunning = false;

  /// App 重启后主动恢复失败订阅数据上报
  ///
  /// 只负责唤醒后台补报任务，不等待队列全部完成，避免阻塞业务启动流程。
  static void retryFailedSubscribtionReports() {
    _startFailedReportsRetry();
  }

  /// 安卓订阅数据上报
  static Future<bool> reportAndroidSubscribtionInfo({
    // 订阅上报接口地址
    required String apiUrl,
    // AES 加密密钥
    required String aesSecretKey,
    // AES 加密 IV
    required String aesIv,
    // 请求头 sct token
    required String aesSctToken,
    // 用户 ID
    required String userId,
    // Google Play 购买 token
    required String purchaseToken,
    // 订阅商品 ID
    required String productId,
    // Google Play 订单 ID
    required String orderId,
    // Google Play base plan ID
    required String basePlanId,
    // Google Play offer ID
    required String offerId,
    // 购买类型
    required String purchaseType,
    // 是否为免费试用
    required bool isFreeTrial,
    // 当前语言地区标识
    required String locale,
  }) async {
    // 获取位置信息
    final location = await _getLocationByIp();

    Map<String, dynamic> params = {
      "userId": userId,
      "purchaseToken": purchaseToken,
      "productId": productId,
      "orderId": orderId,
      "basePlanId": basePlanId,
      "offerId": offerId,
      "purchaseType": purchaseType,
      "freeTrial": isFreeTrial,
      "appVersion": await _getAppVersion(),
      "deviceType": _getDeviceType(),
      "deviceModel": await _getDeviceModel(),
      "deviceOsVersion": await _getDeviceOSVersion(),
      "country": location?.countryCode ?? "",
      "timezone": location?.timezone ?? "",
      "locale": locale,
    };

    final content = _myJsonEncode(params);
    if (content.isEmpty) {
      return false;
    }

    // JSON 或 AES 失败属于本地不可恢复错误，不启动后台重试。
    String encryptedParams = QsAesEncrypt.encrypt(
      secretKey: aesSecretKey,
      iv: aesIv,
      content: content,
    );
    if (encryptedParams.isEmpty) {
      QsLog.error("加密失败");
      return false;
    }

    return _reportEncryptedSubscribtionInfo(
      apiUrl: apiUrl,
      encryptedParams: encryptedParams,
      aesSctToken: aesSctToken,
    );
  }

  /// iOS订阅数据上报
  static Future<bool> reportIOSSubscribtionInfo({
    // 订阅上报接口地址
    required String apiUrl,
    // AES 加密密钥
    required String aesSecretKey,
    // AES 加密 IV
    required String aesIv,
    // 请求头 sct token
    required String aesSctToken,
    // 用户 ID
    required String userId,
    // Firebase Cloud Messaging ID
    required String fcmId,
    // App Store 原始交易 ID
    required String originTransactionId,
    // 原始购买时间戳，单位毫秒
    required String originalPurchaseDateMs,
    // 当前语言地区标识
    required String locale,
  }) async {
    // 获取位置信息
    final location = await _getLocationByIp();
    final attributionToken =
        await QsAsaAttributionInfo.getAttributionToken() ?? "";

    Map<String, dynamic> params = {
      "userId": userId,
      "fcmId": fcmId,
      "appVersion": await _getAppVersion(),
      "deviceType": _getDeviceType(),
      "devicePlatform": await _getDeviceModel(),
      "deviceOSVersion": await _getDeviceOSVersion(),
      "locale": locale,
      "timezone": location?.timezone ?? "",
      "ipCountry": location?.country ?? "",
      "ipState": location?.regionName ?? "",
      "ipCity": location?.city ?? "",
      "attributionToken": attributionToken,
      "originTransactionId": originTransactionId,
      "originalPurchaseDateMs": originalPurchaseDateMs,
    };

    final content = _myJsonEncode(params);
    if (content.isEmpty) {
      return false;
    }

    // JSON 或 AES 失败属于本地不可恢复错误，不启动后台重试。
    String encryptedParams = QsAesEncrypt.encrypt(
      secretKey: aesSecretKey,
      iv: aesIv,
      content: content,
    );
    if (encryptedParams.isEmpty) {
      QsLog.error("加密失败");
      return false;
    }

    return _reportEncryptedSubscribtionInfo(
      apiUrl: apiUrl,
      encryptedParams: encryptedParams,
      aesSctToken: aesSctToken,
    );
  }

  static Future<bool> _reportEncryptedSubscribtionInfo({
    required String apiUrl,
    required String encryptedParams,
    required String aesSctToken,
  }) async {
    final success = await _postEncryptedSubscribtionInfo(
      apiUrl: apiUrl,
      encryptedParams: encryptedParams,
      aesSctToken: aesSctToken,
    );
    if (success) {
      return true;
    }

    await _saveFailedSubscribtionReport(
      // 只持久化已加密内容，避免把明文订阅参数和 AES 信息落盘。
      FailedSubscribtionReport(
        id: _createFailedReportId(),
        apiUrl: apiUrl,
        data: encryptedParams,
        sct: aesSctToken,
        failedCount: 1,
        nextRetryTimeMs: _nextRetryTimeMs(failedCount: 1),
      ),
    );
    _startFailedReportsRetry();
    return false;
  }

  static Future<bool> _postEncryptedSubscribtionInfo({
    required String apiUrl,
    required String encryptedParams,
    required String aesSctToken,
  }) async {
    try {
      var response = await QsNetRequest.getInstance().postJson(
        apiUrl,
        parameters: {"data": encryptedParams},
        headers: {"sct": aesSctToken},
        isShowLoading: false,
        onError: (error) {
          QsLog.error("上报订阅数据失败: ${error.message}");
        },
      );

      if (response?["code"] != 0) {
        QsLog.error("上报订阅数据失败: ${response?["message"] ?? response}");
        return false;
      }
      QsLog.info("上报订阅数据成功");
      return true;
    } catch (e) {
      QsLog.error("上报订阅数据异常: $e");
      return false;
    }
  }

  static void _startFailedReportsRetry() {
    if (_isRetryLoopRunning) {
      return;
    }

    // 防止同一进程内多次失败或多次恢复调用启动并发补报循环。
    _isRetryLoopRunning = true;
    unawaited(_runFailedReportsRetryLoop());
  }

  static Future<void> _runFailedReportsRetryLoop() async {
    try {
      while (true) {
        final reports = await _getFailedSubscribtionReports();
        if (reports.isEmpty) {
          return;
        }

        final nowTimeMs = DateTime.now().millisecondsSinceEpoch;
        // 只处理已到补报时间的数据，未到期的数据继续留在持久化队列中。
        final dueReports = reports
            .where((report) => report.nextRetryTimeMs <= nowTimeMs)
            .toList();

        if (dueReports.isEmpty) {
          final nextRetryTimeMs = reports
              .map((report) => report.nextRetryTimeMs)
              .reduce((a, b) => a < b ? a : b);
          final delayMs = nextRetryTimeMs - nowTimeMs;
          await Future.delayed(
            Duration(
              // 队列内可能存在很久以后的时间戳，这里限制单次等待，方便新数据更快被处理。
              milliseconds: delayMs.clamp(0, _maxRetryDelaySeconds * 1000),
            ),
          );
          continue;
        }

        for (final report in dueReports) {
          final success = await _postEncryptedSubscribtionInfo(
            apiUrl: report.apiUrl,
            encryptedParams: report.data,
            aesSctToken: report.sct,
          );
          if (success) {
            await _removeFailedSubscribtionReport(report.id);
            continue;
          }

          final failedCount = report.failedCount + 1;
          await _replaceFailedSubscribtionReport(
            report.copyWith(
              failedCount: failedCount,
              nextRetryTimeMs: _nextRetryTimeMs(failedCount: failedCount),
            ),
          );
        }
      }
    } finally {
      _isRetryLoopRunning = false;
    }
  }

  static Future<List<FailedSubscribtionReport>>
  _getFailedSubscribtionReports() async {
    try {
      final reportJsonList = await QsStorageTool.getStringList(
        key: _failedReportsStorageKey,
      );
      if (reportJsonList == null || reportJsonList.isEmpty) {
        return [];
      }

      final reports = <FailedSubscribtionReport>[];
      for (final reportJson in reportJsonList) {
        final reportMap = jsonDecode(reportJson);
        if (reportMap is! Map<String, dynamic>) {
          continue;
        }

        final report = FailedSubscribtionReport.fromJson(reportMap);
        if (report.id.isEmpty ||
            report.apiUrl.isEmpty ||
            report.data.isEmpty ||
            report.sct.isEmpty) {
          continue;
        }
        reports.add(report);
      }
      return reports;
    } catch (e) {
      QsLog.error("读取失败订阅上报队列失败: $e");
      return [];
    }
  }

  static Future<void> _saveFailedSubscribtionReport(
    FailedSubscribtionReport report,
  ) async {
    await _replaceFailedSubscribtionReport(report);
    QsLog.info("订阅数据上报失败，已加入后台重试队列");
  }

  static Future<void> _replaceFailedSubscribtionReport(
    FailedSubscribtionReport report,
  ) async {
    try {
      final reports = await _getFailedSubscribtionReports();
      final reportIndex = reports.indexWhere((item) => item.id == report.id);
      if (reportIndex >= 0) {
        reports[reportIndex] = report;
      } else {
        reports.add(report);
      }
      await _setFailedSubscribtionReports(reports);
    } catch (e) {
      QsLog.error("保存失败订阅上报队列失败: $e");
    }
  }

  static Future<void> _removeFailedSubscribtionReport(String id) async {
    try {
      final reports = await _getFailedSubscribtionReports();
      reports.removeWhere((report) => report.id == id);
      await _setFailedSubscribtionReports(reports);
    } catch (e) {
      QsLog.error("移除失败订阅上报队列失败: $e");
    }
  }

  static Future<void> _setFailedSubscribtionReports(
    List<FailedSubscribtionReport> reports,
  ) async {
    final reportJsonList = reports
        .map((report) => jsonEncode(report.toJson()))
        .toList();
    if (reportJsonList.isEmpty) {
      await QsStorageTool.remove(key: _failedReportsStorageKey);
      return;
    }

    await QsStorageTool.setStringList(
      key: _failedReportsStorageKey,
      value: reportJsonList,
    );
  }

  static String _createFailedReportId() {
    return "${DateTime.now().microsecondsSinceEpoch}";
  }

  static int _nextRetryTimeMs({required int failedCount}) {
    return DateTime.now()
        .add(_retryDelay(failedCount: failedCount))
        .millisecondsSinceEpoch;
  }

  static Duration _retryDelay({required int failedCount}) {
    // 前三次使用固定短间隔，之后指数退避，但最大等待不超过 1 分钟。
    if (failedCount <= 1) {
      return const Duration(seconds: 2);
    }
    if (failedCount == 2) {
      return const Duration(seconds: 5);
    }
    if (failedCount == 3) {
      return const Duration(seconds: 10);
    }

    var delaySeconds = 10;
    for (var i = 3; i < failedCount; i++) {
      delaySeconds *= 2;
      if (delaySeconds >= _maxRetryDelaySeconds) {
        return const Duration(seconds: _maxRetryDelaySeconds);
      }
    }
    return Duration(seconds: delaySeconds);
  }

  /// 根据 IP 获取省市区信息
  static Future<IpLocationModel?> _getLocationByIp() async {
    try {
      IpLocationModel? location = await IpLocation.getIpLocation();
      return location;
    } catch (e) {
      QsLog.error("获取位置信息失败: $e");
      return null;
    }
  }

  /// 自定义 JSON 编码
  static String _myJsonEncode(Object? params) {
    try {
      return jsonEncode(params);
    } catch (e) {
      QsLog.error("jsonEncode error: $e");
      return "";
    }
  }

  static Future<String> _getAppVersion() async {
    try {
      return await QsDeviceInfo.getAppVersion() ?? "";
    } catch (e) {
      QsLog.error("获取应用版本失败: $e");
      return "";
    }
  }

  static String _getDeviceType() {
    try {
      return QsDeviceInfo.getDeviceType();
    } catch (e) {
      QsLog.error("获取设备类型失败: $e");
      return "";
    }
  }

  static Future<String> _getDeviceModel() async {
    try {
      return await QsDeviceInfo.getDeviceModel();
    } catch (e) {
      QsLog.error("获取设备型号失败: $e");
      return "";
    }
  }

  static Future<String> _getDeviceOSVersion() async {
    try {
      return await QsDeviceInfo.getDeviceOSVersion();
    } catch (e) {
      QsLog.error("获取设备系统版本失败: $e");
      return "";
    }
  }
}
