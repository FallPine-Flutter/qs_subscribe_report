class QsSubscribeReportIosApiParameterNameModel {
  QsSubscribeReportIosApiParameterNameModel({
    required this.userId,
    required this.fcmId,
    required this.appVersion,
    required this.deviceType,
    required this.deviceModel,
    required this.deviceOSVersion,
    required this.locale,
    required this.timezone,
    required this.ipCountry,
    required this.ipState,
    required this.ipCity,
    required this.attributionToken,
    required this.originTransactionId,
    required this.originalPurchaseDateMs,
  });

  // 用户ID
  final String userId;
  // 推送ID
  final String fcmId;
  // 应用版本
  final String appVersion;
  // 设备类型
  final String deviceType;
  // 设备型号
  final String deviceModel;
  // 设备操作系统版本
  final String deviceOSVersion;
  // 地区
  final String locale;
  // 时区
  final String timezone;
  // IP国家
  final String ipCountry;
  // IP省份
  final String ipState;
  // IP城市
  final String ipCity;
  // 归因Token
  final String attributionToken;
  // 原始交易ID
  final String originTransactionId;
  // 原始交易时间
  final String originalPurchaseDateMs;
}
