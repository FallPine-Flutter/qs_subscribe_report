# qs_subscribe_report

订阅数据上报插件，支持 Android Google Play 订阅信息上报和 iOS App Store 订阅信息上报。

插件会在上报前自动补充 App 版本、设备信息、系统版本、IP 定位信息等公共字段，并使用 AES 加密后提交到业务接口。

## 功能

- Android Google Play 订阅数据上报，支持携带 Google Play 混淆账号 ID。
- iOS App Store 订阅数据上报。
- iOS 内部自动通过 `qs_asa_attribution_info` 获取 Apple Ads attribution token。
- 首次上报失败后，本地保存已加密请求并在后台异步补报。

## 安装

在项目的 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  qs_subscribe_report: ^1.0.2
```

然后执行：

```shell
flutter pub get
```

## 公开方法

| 方法 | 说明 |
| --- | --- |
| `reportAndroidSubscribtionInfo` | 上报 Android Google Play 订阅数据 |
| `reportIOSSubscribtionInfo` | 上报 iOS App Store 订阅数据 |
| `retryFailedSubscribtionReports` | App 重启后唤醒失败订阅数据补报 |

## 失败补报

如果首次网络上报失败、接口无响应或服务端返回非成功状态，插件会把已加密后的请求内容保存到本地队列，并在后台异步补报。

App 重启后，建议在业务初始化完成后主动调用一次恢复方法：

```dart
import 'package:qs_subscribe_report/qs_subscribe_report.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  QsSubscribeReport.retryFailedSubscribtionReports();

  runApp(const MyApp());
}
```

说明：

- `retryFailedSubscribtionReports()` 只负责唤醒后台补报任务，不会等待队列全部完成。
- 上报方法返回的 `bool` 只表示首次请求是否成功，不表示后台补报的最终结果。
- 失败队列只保存已加密的请求内容，不保存明文订阅参数和 AES 密钥信息。
- 补报间隔前几次约为 `2s / 5s / 10s`，之后继续退避重试，最大间隔 `1min`。

## Android 订阅上报

调用 `reportAndroidSubscribtionInfo` 上报 Google Play 订阅数据：

```dart
final success = await QsSubscribeReport.reportAndroidSubscribtionInfo(
  apiUrl: 'https://example.com/api/subscribe/android/report',
  aesSecretKey: 'your aes secret key',
  aesIv: 'your aes iv',
  aesSctToken: 'your sct token',
  userId: 'user_id',
  purchaseToken: 'google_play_purchase_token',
  productId: 'subscription_product_id',
  orderId: 'google_play_order_id',
  basePlanId: 'base_plan_id',
  offerId: 'offer_id',
  purchaseType: 'subscribe',
  isFreeTrial: false,
  obfuscatedAccountId: 'google_play_obfuscated_account_id',
  locale: 'zh_CN',
);

if (success) {
  // 首次上报成功
} else {
  // 首次上报失败；插件会在后台异步补报可重试请求
}
```

### Android 参数说明

| 参数 | 说明 |
| --- | --- |
| `apiUrl` | 订阅上报接口地址 |
| `aesSecretKey` | AES 加密密钥 |
| `aesIv` | AES 加密 IV |
| `aesSctToken` | 请求头 `sct` token |
| `userId` | 用户 ID |
| `purchaseToken` | Google Play 购买 token |
| `productId` | 订阅商品 ID |
| `orderId` | Google Play 订单 ID |
| `basePlanId` | Google Play base plan ID |
| `offerId` | Google Play offer ID |
| `purchaseType` | 购买类型 |
| `isFreeTrial` | 是否为免费试用 |
| `obfuscatedAccountId` | Google Play 混淆账号 ID |
| `locale` | 当前语言地区标识，例如 `zh_CN`、`en_US` |

## iOS 订阅上报

调用 `reportIOSSubscribtionInfo` 上报 App Store 订阅数据：

```dart
final success = await QsSubscribeReport.reportIOSSubscribtionInfo(
  apiUrl: 'https://example.com/api/subscribe/ios/report',
  aesSecretKey: 'your aes secret key',
  aesIv: 'your aes iv',
  aesSctToken: 'your sct token',
  userId: 'user_id',
  fcmId: 'firebase_cloud_messaging_id',
  originTransactionId: 'app_store_original_transaction_id',
  originalPurchaseDateMs: '1710000000000',
  locale: 'zh_CN',
);

if (success) {
  // 首次上报成功
} else {
  // 首次上报失败；插件会在后台异步补报可重试请求
}
```

插件会在 iOS 内部通过 `qs_asa_attribution_info` 获取 Apple Ads attribution token，并随订阅数据一起上报；业务方不需要传入 attribution token。获取失败、系统不支持或当前平台不支持时会降级为空字符串，不阻塞订阅上报。

### iOS 参数说明

| 参数 | 说明 |
| --- | --- |
| `apiUrl` | 订阅上报接口地址 |
| `aesSecretKey` | AES 加密密钥 |
| `aesIv` | AES 加密 IV |
| `aesSctToken` | 请求头 `sct` token |
| `userId` | 用户 ID |
| `fcmId` | Firebase Cloud Messaging ID |
| `originTransactionId` | App Store 原始交易 ID |
| `originalPurchaseDateMs` | 原始购买时间戳，单位毫秒 |
| `locale` | 当前语言地区标识，例如 `zh_CN`、`en_US` |

## 服务端返回约定

插件会向 `apiUrl` 发起 `POST JSON` 请求：

```json
{
  "data": "AES 加密后的订阅上报内容"
}
```

请求头会携带：

```text
sct: aesSctToken
```

当服务端返回的 JSON 中 `code == 0` 时，插件认为上报成功：

```json
{
  "code": 0,
  "message": "success"
}
```

如果响应为空、请求失败或 `code != 0`，插件会认为首次上报失败，并保存到本地队列进行后台补报。

## 注意事项

- JSON 编码失败或 AES 加密失败属于本地不可恢复错误，不会进入失败补报队列。
- iOS Apple Ads attribution token 由插件内部自动获取，调用方不需要也不能通过 `reportIOSSubscribtionInfo` 传入。
- 后台补报只在当前 Dart isolate 存活期间持续运行。
- App 重启后，需要业务方主动调用 `QsSubscribeReport.retryFailedSubscribtionReports()` 恢复本地失败队列。
- 当前公开方法名保留 `Subscribtion` 拼写，以兼容已有调用方。
