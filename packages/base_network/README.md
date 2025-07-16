# base_network

A Dart package providing a robust, extensible network client built on top of Dio, with support for:

- ✅ HTTP/2 and Brotli compression
- ✅ Request/response logging
- ✅ Firebase Performance monitoring
- ✅ Sentry error tracking
- ✅ Caching and retry logic
- ✅ Customizable interceptors
- ✅ Authentication and session management

---

## 🚀 Features

- **Dio-based HTTP client** with advanced configuration
- **Interceptor support** for logging, caching, and monitoring
- **Firebase Performance** integration via [`firebase_performance_dio`](https://pub.dev/packages/firebase_performance_dio)
- **Sentry** integration for error reporting
- **Retry logic** for network resilience
- **Custom error handling** and session management
- Supports `GET`, `POST`, `UPLOAD`, `DOWNLOAD`

---

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  base_network:
    path: packages/base_network
```

---

## ⚙️ Usage

### 1️⃣ Setup Token Manager

Create a class extending `BaseTokenManager` to manage token renewal, silent login, and failures.

```dart
class TokenRenewalHelper extends BaseTokenManager {
  @override
  Future<void> renewToken() async {
    // Implement your token renewal logic
  }

  @override
  Future<void> silentLogin() async {
    // Implement silent login logic
  }

  @override
  void handleSilentLoginFailure() {
    // Handle login failure
  }
}
```

---

### 2️⃣ Create Your Custom Dio Client

Extend `BaseDioClient` to create your own network client.

```dart
class DioImpl extends BaseDioClient {
  DioImpl._internal({
    required CacheManager cacheManager,
    required BaseTokenManager tokenManager,
    required Set<String> urlsShouldNotFire401,
  }) : super(
          cacheManager: cacheManager,
          tokenManager: tokenManager,
          urlsShouldNotFire401: urlsShouldNotFire401,
        );

  factory DioImpl.init({
    required CacheManager cacheManager,
    required BaseTokenManager tokenManager,
    required Set<String> urlsShouldNotFire401,
  }) {
    return DioImpl._internal(
      cacheManager: cacheManager,
      tokenManager: tokenManager,
      urlsShouldNotFire401: urlsShouldNotFire401,
    );
  }
}
```

---

### 3️⃣ Making API Calls

Use `callApiWithDioClient` to make API calls.  
This expects an `ApiRequest` object and returns your response object extending `JsonMessageResponse`.

#### Example POST request

```dart
final Map<String, dynamic> body = {
  'currentPageNumber': 1,
  'pageSize': 35,
  'type': 'mst_collectionsv1',
  'id': '',
  'fromdate': '',
  'todate': '',
};

final request = ApiRequestBuilder()
    .apiIdentifier(ApiIdentifier.rise)
    .requestType(HttpMethod.post)
    .cacheCallback((value) {
      // handle cache response
    })
    .apiKey('A1K6V8N8u0+JNZJLbPUwHw==')
    .url('master/Master/GetDatabyType')
    .request(body)
    .build();

return DioImpl.init(
  cacheManager: CacheManager(),
  tokenManager: TokenRenewalHelper(),
  urlsShouldNotFire401: {'/auth/login', '/auth/refresh'},
).callApiWithDioClient(
  request,
  SchemeDetailsModel.initial(),
).onError<ErrorException>((error, _) {
  throw error;
});
```

---

### 4️⃣ JSON Response Classes

Each response class must extend `JsonMessageResponse` for automatic parsing.

```dart
class SchemeDetailsModel extends JsonMessageResponse {
  List<FundDatum> data;

  SchemeDetailsModel({this.data = const []});

  @override
  void fromJson(Map<String, dynamic> json) {
    super.fromJson(json);
    data.clear();
    if (json['data'] != null) {
      json['data'].forEach((v) {
        data.add(FundDatum.fromJson(v));
      });
    }
  }

  factory SchemeDetailsModel.initial() => SchemeDetailsModel();
}
```

---

### 5️⃣ Initialize CacheManager

Before using the client, initialize `CacheManager` in your `main` method.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheManager().init();
  runApp(MyApp());
}
```

---

## 🚨 Error Handling

This package uses a custom `ErrorException` that extends Dart’s `Exception`.  
Use `.onError` to catch and handle it.

```dart
callApiWithDioClient(request, SchemeDetailsModel.initial())
  .onError<ErrorException>((error, _) {
    // handle or log the error
    throw error;
});
```

---

## 🔗 Related Packages

- [dio](https://pub.dev/packages/dio) - Powerful HTTP client for Dart
- [firebase_performance_dio](https://pub.dev/packages/firebase_performance_dio) - Integrates Firebase Performance
- [sentry_dart](https://pub.dev/packages/sentry) - For error tracking

---

## 📝 License

This project is licensed under the MIT License.
