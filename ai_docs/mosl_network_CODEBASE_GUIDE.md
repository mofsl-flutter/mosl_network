# mosl_network — Codebase Guide

> Flutter network package for the MOFSL (Motilal Oswal) app ecosystem. Provides a unified HTTP client, multi-protocol response handling (Protobuf + JSON), cache management, token renewal, and local preference abstractions over Dio.

**Package name:** `mosl_network`  
**Version:** 1.0.0+1  
**SDK constraint:** `>=3.6.0 <4.0.0`  
**Publish:** private (`publish_to: none`)  
**Entry point:** `lib/main.dart` (demo app; library code lives under `lib/network/` and `lib/shared_preference/`)

---

## Table of Contents

1. [Quick-Start / Initialization](#1-quick-start--initialization)
2. [Architecture Overview](#2-architecture-overview)
3. [Core Network Layer](#3-core-network-layer)
   - [DioImpl](#dioimpl)
   - [CacheManager](#cachemanager)
   - [ResponseExtension](#responseextension)
4. [Request Construction](#4-request-construction)
   - [ApiRequest / ApiRequestBuilder](#apirequest--apirequestbuilder)
   - [ApiIdentifier](#apiidentifier)
   - [HttpMethod](#httpmethod)
5. [Header System](#5-header-system)
   - [HeaderBaseOptions](#headerbaseoptions)
   - [ProtoApiHeader](#protoapiheader)
   - [JsonApiHeader](#jsonapiheader)
6. [Preferences & Local Storage](#6-preferences--local-storage)
   - [SharedPreferencesProvider](#sharedpreferencesprovider)
   - [Preferences](#preferences)
   - [Preference Type Implementations](#preference-type-implementations)
7. [Token Management](#7-token-management)
   - [TokenRenewalHelper](#tokenrenewalhelper)
   - [TokenRenewalRepository](#tokenrenewalrepository)
8. [Interceptors](#8-interceptors)
   - [ApiInterceptor](#apiinterceptor)
   - [LoggingInterceptor](#logginginterceptor)
9. [Exception Handling](#9-exception-handling)
   - [Error Types](#error-types)
   - [getErrorFromException2](#geterrorfrromexception2)
   - [ErrorCategoryEnum](#errorcategoryenum)
10. [Data Models](#10-data-models)
    - [Response Framework](#response-framework)
    - [ApiStatus](#apistatus)
    - [Protobuf Models](#protobuf-models)
    - [JSON Domain Models](#json-domain-models)
11. [Constants & URL Configuration](#11-constants--url-configuration)
12. [UI Demo Screens](#12-ui-demo-screens)
13. [Request / Response Flow](#13-request--response-flow)
14. [Initialization Order & Failure Modes](#14-initialization-order--failure-modes)
15. [Cross-Cutting Patterns](#15-cross-cutting-patterns)
16. [Gotchas & Anti-Patterns](#16-gotchas--anti-patterns)

---

## 1. Quick-Start / Initialization

### pubspec.yaml (consumer additions)
```yaml
dependencies:
  mosl_network:
    path: ../mosl_network   # or git URL

  # Peer dependencies (not re-exported)
  dio: ^5.8.0+1
  shared_preferences: ^2.5.3
  connectivity_plus: ^6.1.4
  protobuf: ^4.0.0
  path_provider: ^2.0.0
  image_picker: any
  image_cropper:
    git:
      url: https://github.com/hnvn/flutter_image_cropper.git
      ref: master
  permission_handler: any
```

### Mandatory initialization in `main()`
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Step 1: init SharedPreferences + Cache in parallel
  await Future.wait([
    SharedPreferencesProvider.init(),
    CacheManager().init(),
  ]);

  // Step 2: Seed credential store
  Preferences.init(
    token: '<access_jwt>',
    userAgent: 'Android/14/SuperApp/6.0.28(UAT-27)_6025/IN/<uuid>',
    refreshToken: '<refresh_jwt>',
  );

  // Step 3: Wire up the HTTP client
  DioImpl.init(
    cacheManager: CacheManager(),
    tokenManager: TokenRenewalHelper(),
    urlsShouldNotFire401: {'Login/RenewSession', 'Login/Token'},
  );

  runApp(const MyApp());
}
```

> **Any reversal of steps 1→2→3 will produce runtime errors.** See [§14](#14-initialization-order--failure-modes).

---

## 2. Architecture Overview

### Layer Diagram
```
Consumer App
        ↓
DioImpl (Singleton HTTP client)
  ├─ ApiInterceptor     ← header injection, fallback URL rotation
  ├─ LoggingInterceptor ← debug output (suppressed in release)
  └─ CacheInterceptor   ← Hive-backed persistent cache
        ↓
ApiRequest<T> (built via ApiRequestBuilder<T>)
  ├─ ProtoApiHeader / JsonApiHeader   ← API-specific headers
  └─ ApiIdentifier                    ← routes to base URL
        ↓
Response.handleResponse<T>()          ← format-agnostic parsing
  ├─ Protobuf path: BaseResponse.fromBuffer → unpack into T
  └─ JSON path: JsonMessageResponse.fromJson(data)
        ↓
Typed T (GeneratedMessage or JsonMessageResponse subclass)
```

### Multi-API Routing
| `ApiIdentifier` | Base URL | Protocol |
|---|---|---|
| `rise` | `https://dic541g2t9.execute-api.ap-south-1.amazonaws.com/dev/` | JSON |
| `trader` | `https://tradingapi.motilaloswaluat.com/TradingApiV2/` | Protobuf |
| `mPinLogin` | `https://api.dev.riseapp.in/userlogin/` | Protobuf |
| `login`, `eDuMo`, `accountAggregator`, `pwm` | Resolved externally | — |
| `unknown` | No prefix appended | — |

### Dependency Graph (key classes)
```
DioImpl
  └── CacheManager         ← HiveCacheStore backing
  └── TokenRenewalHelper   ← extends BaseTokenManager
       └── TokenRenewalRepository
  └── ApiInterceptor       ← Singleton
  └── Preferences          ← Singleton (reads tokens)
       └── SharedPreferencesProvider ← Singleton (SharedPreferences)
```

---

## 3. Core Network Layer

### DioImpl

**File:** `lib/network/dio_impl.dart`  
**Pattern:** Singleton, factory `DioImpl.init(...)` — subsequent `DioImpl()` calls return the same instance.  
**Extends:** `BaseDioClient` (from `base_network` package)

#### Factory initializer
```dart
DioImpl.init({
  required CacheManager cacheManager,
  required BaseTokenManager tokenManager,
  required Set<String> urlsShouldNotFire401,
})
```
Registers the interceptor chain in order: `ApiInterceptor`, `LoggingInterceptor`, `CacheInterceptor`.

#### Primary method
```dart
Future<T> callApiWithDioClient<T extends Object>(
  ApiRequest apiRequest,
  T response, [
  Duration? maxStale,
])
```
- Calls `_appendUrl(fromRise, apiRequest)` to prepend the correct base URL.
- Selects Dio method based on `apiRequest.requestType` (`HttpMethod`).
- For `HttpMethod.download`: calls `dio.download(url, savePath, onReceiveProgress)`.
- For `HttpMethod.upload`: calls `dio.post(url, data: FormData)`.
- For Protobuf requests: serialises `GeneratedMessage.writeToBuffer()` before sending.
- Calls `response.handleResponse<T>(response)` after receiving raw `Response`.
- On `DioException` with status 401: triggers `_handleReLogin()` → `_tokenManager.renewToken()` → retries once.
- Excluded endpoints (`_urlsShouldNotFire401`) skip the 401 retry loop.

#### Internal helpers
| Method | Signature | Notes |
|---|---|---|
| `_appendUrl` | `ApiRequest _appendUrl(bool fromRise, ApiRequest opts)` | Prepends `riseBaseUrl` or `traderBaseUrl` based on `ApiIdentifier` |
| `_handleReLogin` | `void _handleReLogin()` | Calls `_tokenManager.renewToken()`, updates `ApiInterceptor.headers` |

---

### CacheManager

**File:** `lib/network/dio_cache_manager.dart`  
**Pattern:** Singleton  
**Backing store:** `HiveCacheStore` (from `dio_cache_interceptor_hive_store`)  
**Default TTL:** 12 hours

#### Initialization
```dart
Future<void> init()
```
Resolves app documents directory via `path_provider`, initialises `HiveCacheStore`.

#### Key methods
| Method | Signature | Notes |
|---|---|---|
| `isExist` | `Future<bool> isExist(String key)` | Checks if a cache entry exists |
| `get` | `Future<CacheResponse?> get(String key)` | Retrieves raw `CacheResponse` |
| `getActualRes<T>` | `Future<T?> getActualRes({required String key, HttpMethod method, required T runtimeType})` | Decodes cached bytes into typed `T` via `handleResponse` |
| `getCacheOptions` | `CacheOptions getCacheOptions(bool isForcedCacheEnable, bool checkConnectivity, Duration? maxStale)` | Returns `CacheOptions` for each request |
| `delete` | `Future<void> delete(String url)` | Removes a single entry by URL |
| `clearCacheOnLogout` | `Future<void> clearCacheOnLogout()` | Clears full cache |
| `clearCacheOnAppUpdate` | `Future<void> clearCacheOnAppUpdate()` | Clears full cache on app version change |
| `splitIfPossible` | `String splitIfPossible(String url)` | Normalises URL by stripping domain — used as cache key |

#### Cache policy logic (inside `getCacheOptions`)
| Condition | `CachePolicy` |
|---|---|
| `isForcedCacheEnable == true` | `CachePolicy.refreshForceCache` |
| `checkConnectivity == false` (offline) | `CachePolicy.forceCache` |
| Default | `CachePolicy.request` |
| On error (network failure) | `CachePolicy.forceCache` (serves stale content) |

---

### ResponseExtension

**File:** `lib/network/extentions.dart`  
**Type:** Extension on `Response` (Dio)

```dart
T handleResponse<T extends Object>(T responseType, {bool isFromCache = false})
```

**Dispatch logic:**
```
IF responseType is GeneratedMessage (Protobuf):
    BaseResponse envelope = BaseResponse.fromBuffer(response.data)
    SWITCH envelope.whichDataOrError():
      case DataOrError.data  → envelope.data.unpackInto(responseType) → return T
      case DataOrError.error → throw via getErrorFromException2(envelope.error)
      case DataOrError.notSet → throw ErrorException

ELSE IF responseType is NoResponse:
    return responseType as T   // no-op; endpoint returns nothing

ELSE (JSON):
    res = response.data as Map<String,dynamic>
    Parse ApiStatus if "status" key exists
    (responseType as JsonMessageResponse).fromJson(res)
    return responseType as T

CATCH _TypeError:
    debugPrint + rethrow as ErrorException
```

---

## 4. Request Construction

### ApiRequest / ApiRequestBuilder

**File:** `lib/network/helper/api_request_builder.dart`

`ApiRequest<T>` is **not constructed directly** — always use the fluent builder.

```dart
ApiRequest<T> request = ApiRequestBuilder<T>()
    .url('api/Quote/PlaceOrderData')
    .request(myRequestObject)          // optional body
    .requestType(HttpMethod.get)
    .apiIdentifier(ApiIdentifier.trader)
    .apiVersion(Constants.apiV2_1)
    .forcedCache(false)
    .isTokenRequired(true)
    .build();
```

#### `ApiRequestBuilder<T>` — all chaining methods
| Method | Type | Default |
|---|---|---|
| `.url(String)` | required | — |
| `.request(T)` | body (Protobuf `GeneratedMessage` or `Map`) | null |
| `.rawRequest(T)` | raw body override | null |
| `.requestType(HttpMethod)` | HTTP verb | `HttpMethod.get` |
| `.cancelToken(CancelToken)` | Dio cancel token | null |
| `.responseType(ResponseType)` | Dio response type | auto-inferred |
| `.onReceiveProgress(ProgressCallback)` | download progress | null |
| `.savePath(String)` | download destination path | null |
| `.specialToken(String?)` | overrides stored access token | null |
| `.forcedCache(bool)` | force serve from cache | false |
| `.internetAvailable(bool)` | manual connectivity hint | true |
| `.cacheAvailable(bool)` | enable cache reads | true |
| `.apiVersion(String)` | `X-Api-Version` header value | `'1.0'` |
| `.apiIdentifier(ApiIdentifier)` | routes to base URL | `ApiIdentifier.unknown` |
| `.isTokenRequired(bool)` | include Bearer token | true |
| `.apiKey(String)` | `XApiKey` header (JSON APIs) | null |
| `.cacheCallback(void Function(T))` | called on cache hit | null |
| `.build()` | → `ApiRequest<T>` | — |

**Response type auto-inference (in `build()`):**
- `ApiIdentifier.trader` or `ApiIdentifier.mPinLogin` → `ResponseType.bytes` (Protobuf)
- All others → `ResponseType.json`

#### `ApiRequest<T>` — computed properties
| Property | Type | Notes |
|---|---|---|
| `headers` | `HeaderBaseOptions` | Returns `ProtoApiHeader` for bytes, `JsonApiHeader` for JSON |
| `userAgent` | `String` | Reads from `Preferences().userAgent` |

---

### ApiIdentifier

**File:** `lib/network/helper/api_request_builder.dart`  
**Type:** Enum

| Value | Description |
|---|---|
| `rise` | Rise/MOFSL REST API (JSON) |
| `trader` | Trading API (Protobuf over HTTPS) |
| `eDuMo` | eDuMo service |
| `login` | Login service |
| `accountAggregator` | Account Aggregator service |
| `mPinLogin` | MPIN/Session login service (Protobuf) |
| `pwm` | PWM service |
| `unknown` | No base URL prepended |

**Computed getters:**
```dart
bool get isPWM       // == pwm
bool get isRise      // == rise
bool get isMPinLogin // == mPinLogin
```

---

### HttpMethod

**Source:** `base_network` package  
**Values used:** `get`, `post`, `put`, `delete`, `download`, `upload`

---

## 5. Header System

### HeaderBaseOptions

**File:** `lib/network/helper/header_base_options.dart`  
**Type:** Abstract class

| Property | Type | Notes |
|---|---|---|
| `accept` | `String` | abstract |
| `contentType` | `String` | abstract |
| `isTokenRequired` | `bool` | |
| `cacheCallback` | `void Function(Response)?` | optional |
| `authorization` | `String?` | abstract getter |

**`toJson` getter** — returns `Map<String, String>`:
```dart
{
  'accept': accept,
  'Content-Type': contentType,
  'accept-encoding': 'br',
  'Authorization': 'Bearer $authorization',  // only if isTokenRequired && authorization != null
}
```

---

### ProtoApiHeader

Used for `ApiIdentifier.trader` and `ApiIdentifier.mPinLogin` (Protobuf endpoints).

```dart
const ProtoApiHeader({
  required String xApiVersion,
  required String userAgent,
  String? specialToken,
})
```

- `accept` / `contentType` → `Constants.contentTypeProtobuf` (`application/x-protobuf`)
- `authorization` → `specialToken ?? Preferences().accessToken.getOrDefault()`
- Additional header keys: `'X-Api-Version'`, `'User-Agent'`

---

### JsonApiHeader

Used for `ApiIdentifier.rise` and other JSON endpoints.

```dart
JsonApiHeader({
  String? xApiKey,
  required String xApiVersion,
  required String userAgent,
  String? specialToken,
})
```

- `accept` / `contentType` → `Constants.json` (`application/json`)
- `authorization` → `specialToken ?? Preferences().accessToken.getOrDefault()`
- Additional header keys: `'XApiKey'` (if present), `'X-Api-Version'`, `'User-Agent'`

---

## 6. Preferences & Local Storage

### SharedPreferencesProvider

**File:** `lib/shared_preference/shared_preferences_provider.dart`  
**Pattern:** Static singleton facade around `SharedPreferences`

```dart
await SharedPreferencesProvider.init();         // call once in main()
SharedPreferences prefs = SharedPreferencesProvider.instance;
bool ready = SharedPreferencesProvider.isInitiated;
```

- `instance` asserts if called before `init()`.
- Initialization errors are caught and logged via `debugPrint`.

---

### Preferences

**File:** `lib/network/helper/preferences.dart`  
**Pattern:** Singleton  
**Depends on:** `SharedPreferencesProvider.instance`

#### Factory initializer
```dart
Preferences.init({
  required String token,
  required String userAgent,
  required String refreshToken,
})
```
Seeds `accessToken`, `userAgent`, and `refreshToken` preference entries.

#### Instance properties (all `PreferenceBase` subclasses)
| Property | Key | Type |
|---|---|---|
| `accessToken` | `app:access_token` | `StringPreference` |
| `userAgent` | `app:user_agent` | `StringPreference` |
| `refreshToken` | `app:refresh_token` | `StringPreference` |
| `primaryUrlWorking` | `app:primary_url_working` | `BooleanPreference` |
| `currentUrlIndex` | `app:current_fallback_url_index` | `IntPreference` |

---

### Preference Type Implementations

**File:** `lib/network/helper/preferences_base.dart`

All implementations extend the abstract `PreferenceBase`:
```dart
abstract class PreferenceBase {
  SharedPreferences get preferences;  // → SharedPreferencesProvider.instance
  String get key;
  bool get isSet;
  bool get isNotSet;
  Future<void> delete();
}
```

| Class | `get()` | `getOrDefault({def})` | `set(value)` | Notes |
|---|---|---|---|---|
| `StringPreference` | `String?` | `String` | `Future<void>` | |
| `SecureStringPreference` | `String?` | — | — | Returns null if `!isSet` |
| `IntPreference` | `int?` | `int` (def: 0) | `Future<void>` | |
| `BooleanPreference` | `bool?` | `bool` (def: false) | `Future<void>` | |
| `MapPreference` | `Map<String,dynamic>?` | `Map` (def: {}) | `Future<void>` | JSON-serialised |
| `StringListPreference` | `List<String>?` | `List<String>` | `Future<void>` | |
| `BinaryPreference` (abstract) | `Uint8List?` | — | `Future<void>` | Base64-encoded string |

---

## 7. Token Management

### TokenRenewalHelper

**File:** `lib/network/helper/token_renewal.dart`  
**Pattern:** Singleton with `_internal` constructor  
**Extends:** `BaseTokenManager` (from `base_network`)

| Method / Property | Signature | Notes |
|---|---|---|
| `renewToken` | `Future<String> renewToken()` | Calls `callSilentLogin(false)`, returns new access token |
| `callSilentLogin` | `Future<SilentLoginStatus> callSilentLogin(bool isForce)` | Delegates to `TokenRenewalRepository` |
| `handleSilentLoginFailure` | `void handleSilentLoginFailure()` | Called when silent login fails — triggers app-level re-login |
| `writeLogs` | `void writeLogs(String title, String message)` | Debug logging |
| `shouldCallRefreshToken` | `bool` (mutable) | Flag read by interceptor logic |
| `isTokenValid` | `bool` (getter) | Checks `Preferences().refreshToken.isSet` |

---

### TokenRenewalRepository

**File:** `lib/network/data/token_renewal_repository.dart`  
**Pattern:** Singleton

#### `refreshToken()`
```dart
Future<String> refreshToken()
```
- `GET api/Login/Token`
- `ApiIdentifier.mPinLogin`, `isTokenRequired: false`, `specialToken: refreshToken`
- Response type: `TokenResponse` (Protobuf)
- Side effect: writes new `accessToken` to `Preferences`

#### `silentAuth()`
```dart
Future<SilentLoginStatus> silentAuth()
```
- `GET api/Login/RenewSession`
- `ApiIdentifier.mPinLogin`, `specialToken: refreshToken`
- Response type: `TokenInfo` (Protobuf)
- Returns `SilentLoginStatus.success` or `SilentLoginStatus.failed`

> Both endpoints are in `urlsShouldNotFire401` — they will **not** trigger a recursive 401 renewal loop.

---

## 8. Interceptors

### ApiInterceptor

**File:** `lib/network/interceptors/dio_api_interceptor.dart`  
**Pattern:** Singleton  
**Extends:** `Interceptor` (Dio)

| Property / Method | Notes |
|---|---|
| `headers: HeaderBaseOptions` | `late`, set by `DioImpl` before each request via `setHeaders()` |
| `fallBackSchemaHost: Map<int, Uri>` | Infrastructure for fallback URL rotation (currently empty) |
| `setHeaders(HeaderBaseOptions)` | Called per-request to update header context |
| `onRequest(RequestOptions, handler)` | Injects `headers.toJson` into request headers; checks `cacheCallback` and calls it if cache hit found |
| `onError(DioException, handler)` | Handles connection/timeout errors; rotates to next fallback URL and updates `Preferences().primaryUrlWorking` |

**Fallback URL rotation (in `onError`):**
1. Looks up `fallBackSchemaHost` for `currentUrlIndex + 1`.
2. Rewrites `options.baseUrl` and increments `currentUrlIndex`.
3. `primaryUrlWorking` set to `false` on first failure, `true` on successful request.

---

### LoggingInterceptor

**File:** `lib/network/interceptors/loging_interceptor.dart`  
**Extends:** `Interceptor` (Dio)

```dart
LoggingInterceptor({
  bool request = true,
  bool requestHeader = true,
  bool requestBody = false,
  bool responseHeader = true,
  bool responseBody = false,
  bool error = true,
})
```

All output via `debugPrint` — **no output in release builds**. Enable `requestBody`/`responseBody` only for local debugging (high noise).

---

## 9. Exception Handling

### Error Types

| Class | Source | Notes |
|---|---|---|
| `ErrorException` | `base_network` | Primary typed error — all public surfaces throw this |
| `ApiError` | Protobuf model | Returned inside `BaseResponse.error` |
| `JsonApiError` | `lib/network/models/json_message_response.dart` | Parsed from JSON error payloads |
| `ApiException` | Wraps `ApiError` | Implements `Exception` |
| `ApiTimeout` | `base_network` | Network timeout |
| `ApiFailure` | `base_network` | Non-200 HTTP failure |
| `ApiCallFailure` | `base_network` | Lower-level call failure |

---

### getErrorFromException2

**File:** `lib/network/helper/exceptions.dart`

```dart
ErrorException getErrorFromException2(
  dynamic err, {
  String key = "",
  bool isCacheEnabled = false,
})
```

Converts any thrown value into a typed `ErrorException`:

| Input type | Output |
|---|---|
| `ErrorException` | passthrough |
| `JsonApiError` | `ErrorException(message: err.errorMessage, ...)` |
| `ApiError` (Protobuf) | `ErrorException(message: err.message, statusCode: err.statusCode)` |
| `ApiTimeout` / `ApiFailure` / `ApiCallFailure` | `ErrorException(message: ..., statusCode: ...)` |
| `ApiException` | Unwraps inner `ApiError` |
| `DioException.connectionTimeout` | `ErrorException` with timeout message |
| `DioException.badResponse` | Checks status code; 401 → unauthorised message |
| `String "No Internet Connection"` | `ErrorException` with `noData` category |
| `ArgumentError` / `UnimplementedError` / `TypeError` | `ErrorException` with raw message |
| Any other | Fallback `ErrorException` |

---

### ErrorCategoryEnum

**File:** `lib/network/models/json_message_response.dart`

| Value | Int code | Meaning |
|---|---|---|
| `unknown` | 0 | Unclassified error |
| `badRequest` | 1 | Malformed request |
| `validation` | 2 | Input validation failure |
| `unauthorized` | 3 | Auth failure |
| `noData` | 4 | Empty result / offline |
| `serverError` | 5 | Backend 5xx |

**Factory:**
```dart
factory ErrorCategoryEnum.valueOf(dynamic errorCode)
// Accepts int (0–5) or String ('Unknown', 'BadRequest', …)
```

**Boolean getters:** `isUnknown`, `isBadRequest`, `isValidation`, `isUnauthorized`, `isNoData`, `isServerError`

---

## 10. Data Models

### Response Framework

#### `NoResponse`
**File:** `lib/network/models/no_response.dart`  
Empty marker class. Use as `T` when the API endpoint returns no body:
```dart
DioImpl().callApiWithDioClient(request, NoResponse())
```

#### `JsonMessageResponse` (Abstract)
**File:** `lib/network/models/json_message_response.dart`

```dart
abstract class JsonMessageResponse {
  String message;
  bool status;
  Map<String, dynamic> get toJson;
  void fromJson(Map<String, dynamic> json);  // populates status and message
}
```

Parsing logic in `fromJson`:
- `status` field: accepts `bool` or `String` → converted via `ApiStatus.fromStatus()`
- Subclasses override `fromJson` to add domain fields

**Concrete subclasses:**

| Class | Extra field | `fromJson` source |
|---|---|---|
| `MessageResponse` | `dataMessage: String` | `json['data']` as String or nested object |
| `AwsMessageResponse` | `dataMessage: String` | `json['message']` directly |

---

### ApiStatus

**Type:** Enum

| Value | String representation |
|---|---|
| `success` | `"Success"` |
| `failure` | `"Failure"` |

```dart
factory ApiStatus.fromStatus(dynamic status)
// "Failed", "Failure", false → failure
// "Success", true → success
// Others → throws FlutterError
```

**Getters:** `bool get isSuccess`, `bool get isFailure`

---

### JsonApiError

**File:** `lib/network/models/json_message_response.dart`

```dart
JsonApiError({
  required String errorMessage,
  required String localisedErrorMessage,
  String? identifier,
  required dynamic errorCategory,
  required ErrorCategoryEnum errorCategoryValue,
  required int errorCode,
})
```

- `factory JsonApiError.fromJson(Map<String, dynamic>)` — parses server error payloads
- `operator ==` compares `errorCategory` + `errorCode`

---

### Protobuf Models

**Location:** `lib/network/models/`  
**Generated from:** `.proto` source definitions  
**File pattern per model:** `ModelName.pb.dart`, `ModelName.pbenum.dart`, `ModelName.pbjson.dart`

**Key modules and types:**

| Module folder | Key types |
|---|---|
| `Base/` | `BaseResponse` (envelope), `ApiError` |
| `Login/` | `AuthRequest`, `TokenInfo`, `TokenResponse`, `GeneratePasswordRequestV2`, `GeneratePasswordResponseV2` |
| `Quote/` | `PlaceOrderData2` |
| `User/` | `ProfilePictureResponse` |
| `Markets/` | Market data models |
| `Portfolio/` | Portfolio models |
| `MF/` (Mutual Funds) | MF-specific models |
| `Home/` | Home screen models |

**`BaseResponse` structure (critical):**
```protobuf
message BaseResponse {
  oneof DataOrError {
    google.protobuf.Any data  = 1;
    ApiError            error = 2;
  }
}
```
All Protobuf responses are unwrapped from this envelope inside `handleResponse`.

> Do not reference `.pb.dart` files directly in business logic — always work through `callApiWithDioClient<T>()` with the typed response object.

---

### JSON Domain Models

#### `SchemeDetailsModel` (extends `JsonMessageResponse`)
**File:** `lib/network/models/fund_details_model.dart`

```dart
SchemeDetailsModel.initial()  // factory for use as response placeholder
```

**Properties:** `data: List<FundDatum>`

**`FundDatum`** — 70+ fields covering:
- Identifiers: `schemeName`, `category`, `subCategory`, `isin`, `schemeCode`
- Financials: `nav`, `minInitialInvestment`, `exitLoad`, `expenseRatio`
- Return series: `ret1Month` → `ret10Year`, `sipRet1Month` → `sipRet10Year`
- Benchmark: benchmark names + returns
- FD rates: `FD3Month` → `FDMax`
- Allocation: `equityPerc`, `largePerc`, `midPerc`, `smallPerc`
- Meta: `ratings`, `amcLogo`, `fundManagers: List<FundManagerData>`, date fields

Nested classes: `MarketCapData`, `FundManagerData`

#### `StoryBannerModel` (extends `JsonMessageResponse`)
**File:** `lib/network/models/story_banner_model.dart`

```dart
StoryBannerModel.initial()  // factory for use as response placeholder
```

**Properties:** `statusCode: int?`, `data: List<Data>`

**`Data`** — 19 fields: `storyId`, `title`, `shortDescription`, `longDescription`, `imageUrl`, `sequence`, `isActive`, `startDate`, `endDate`, `redirectionType`, `redirectionLink`, `contentPlacement`, `sourceApplication`, `mapToAssets`, `eventName`, `eventParameter`, `eventParameterValue`, `access`, `isNewVisible`

---

## 11. Constants & URL Configuration

### Constants

**File:** `lib/network/helper/constants.dart`

```dart
Constants.networkTimeOut   // 20 (seconds)
Constants.contentTypeProtobuf  // 'application/x-protobuf'
Constants.json                 // 'application/json'

// API version strings
Constants.apiV1_0  'apiV1_1'  'apiV1_2'
Constants.apiV2_0  'apiV2_1'  'apiV2_2'
Constants.apiV3_0  'apiV3_1'  'apiV3_2'
Constants.apiV4_0  'apiV4_1'  'apiV4_2'  'apiV4_3'
```

### URL Paths

**File:** `lib/network/helper/url_paths.dart`

| Constant | Value |
|---|---|
| `riseBaseUrl` | `https://dic541g2t9.execute-api.ap-south-1.amazonaws.com/dev/` |
| `traderBaseUrl` | `https://tradingapi.motilaloswaluat.com/TradingApiV2/` |
| `mPinLoginUrl` | `https://api.dev.riseapp.in/userlogin/` |

### MutualFundRequestParams

**File:** `lib/network/helper/mutual_fund_api_request_params.dart`  
90+ `static const String` values for mutual fund API parameter names (e.g., `orderType`, `transactionType`, `mandateId`, `isin`, `clientId`). Use these constants as keys when constructing request maps for MF endpoints.

---

## 12. UI Demo Screens

These screens are part of the demo app (`lib/main.dart`). They are **not library code** — they demonstrate usage patterns.

| Screen | Route | Purpose |
|---|---|---|
| `ProtoScreen` | `/proto` | Protobuf GET (PlaceOrderData) and POST (GeneratePassword) |
| `JsonScreen` | `/json` | JSON GET (StoryBanner) and POST (SchemeDetails) |
| `DownloadScreen` | `/download` | File download with progress tracking |
| `CameraUploadScreen` | `/upload` | Camera capture → crop → multipart upload |

### CameraUploadScreen — upload flow
```dart
// 1. Request camera permission
await Permission.camera.request();

// 2. Pick from camera
XFile? file = await ImagePicker().pickImage(source: ImageSource.camera);

// 3. Crop
CroppedFile? cropped = await ImageCropper().cropImage(sourcePath: file.path, ...);

// 4. Build FormData
FormData formData = FormData.fromMap({
  'file': MultipartFile.fromBytes(
    croppedFile.readAsBytesSync(),
    filename: basename(croppedFile.path),
    contentType: MediaType("image", "png"),
  )
});

// 5. Call API
await DioImpl().callApiWithDioClient(
  ApiRequestBuilder<FormData>()
    .url('api/UserProfile/ProfilePictureUpload')
    .request(formData)
    .requestType(HttpMethod.upload)
    .apiIdentifier(ApiIdentifier.trader)
    .apiVersion(Constants.apiV3_0)
    .build(),
  ProfilePictureResponse(),
);
```

### DownloadScreen — download flow
```dart
final filePath = '${(await getApplicationDocumentsDirectory()).path}/${basename(url)}';

await DioImpl().callApiWithDioClient(
  ApiRequestBuilder<NoResponse>()
    .url(url)
    .savePath(filePath)
    .requestType(HttpMethod.download)
    .onReceiveProgress((count, total) => setState(() => _progress = count / total))
    .build(),
  NoResponse(),
);
```

---

## 13. Request / Response Flow

### Protobuf POST
```
ApiRequestBuilder<GeneratePasswordRequestV2>()
  .url('api/Login/GeneratePassword')
  .request(GeneratePasswordRequestV2(input: 'AA020'))
  .apiIdentifier(ApiIdentifier.trader)
  .requestType(HttpMethod.post)
  .apiVersion(Constants.apiV1_1)
  .isTokenRequired(false)
  .build()
          ↓
ApiRequest: responseType=bytes, headers=ProtoApiHeader
          ↓
DioImpl._appendUrl()  →  traderBaseUrl + url
          ↓
ApiInterceptor.onRequest()  →  injects ProtoApiHeader.toJson into Dio options
          ↓
dio.post(url, data: request.writeToBuffer(), options: bytes)
          ↓
Response<Uint8List>
          ↓
response.handleResponse<GeneratePasswordResponseV2>()
  →  BaseResponse.fromBuffer(data)
  →  envelope.data.unpackInto(GeneratePasswordResponseV2())
  →  return GeneratePasswordResponseV2
```

### JSON POST with cache callback
```
ApiRequestBuilder<SchemeDetailsModel>()
  .url('master/Master/GetDatabyType')
  .request({ currentPageNumber: 1, pageSize: 35, type: 'mst_collectionsv1' })
  .apiIdentifier(ApiIdentifier.rise)
  .requestType(HttpMethod.post)
  .apiKey('A1K6V8N8u0+JNZJLbPUwHw==')
  .cacheCallback((cached) { /* use cached data */ })
  .build()
          ↓
ApiRequest: responseType=json, headers=JsonApiHeader(xApiKey=...)
          ↓
ApiInterceptor.onRequest()
  →  IF cacheCallback set AND cache hit: calls cacheCallback, short-circuits
  →  ELSE: injects JsonApiHeader.toJson, proceeds
          ↓
CacheInterceptor checks Hive store
          ↓
dio.post(url, data: body, options: json)
          ↓
Response<Map<String,dynamic>>
          ↓
response.handleResponse<SchemeDetailsModel>()
  →  (responseType as JsonMessageResponse).fromJson(data)
  →  return SchemeDetailsModel
```

---

## 14. Initialization Order & Failure Modes

### Required initialization sequence
```
1. WidgetsFlutterBinding.ensureInitialized()
2. Future.wait([SharedPreferencesProvider.init(), CacheManager().init()])
3. Preferences.init(token, userAgent, refreshToken)
4. DioImpl.init(cacheManager, tokenManager, urlsShouldNotFire401)
5. runApp(...)
```

### Failure modes
| Violation | Runtime error |
|---|---|
| `SharedPreferencesProvider.instance` before `init()` | `AssertionError` |
| `DioImpl()` before `DioImpl.init()` | `LateInitializationError` |
| `CacheManager()` before `init()` | Hive `BoxNotOpenError` |
| `Preferences.init()` before `SharedPreferencesProvider.init()` | Null `SharedPreferences` instance |
| Token not seeded via `Preferences.init()` | Empty `Authorization` header; 401 on all calls |
| Endpoints missing from `urlsShouldNotFire401` used for token renewal | Infinite 401 renewal loop |

---

## 15. Cross-Cutting Patterns

### Singleton factories
`DioImpl`, `CacheManager`, `Preferences`, `TokenRenewalHelper`, `TokenRenewalRepository`, `ApiInterceptor`, `SharedPreferencesProvider` all use private/internal constructors. Calling `ClassName()` after `init()` returns the same instance.

### Fluent builder for requests
All HTTP calls must go through `ApiRequestBuilder<T>().…build()`. Never construct `ApiRequest` directly — constructor is private.

### `NoResponse` as type argument
When the endpoint returns an empty body (204, etc.), use `NoResponse()` as the `response` argument:
```dart
DioImpl().callApiWithDioClient(request, NoResponse())
```

### Cache callback pattern
The `cacheCallback` on `ApiRequestBuilder` is invoked **before** the network call if a cache hit is found. Use it to immediately render stale data while a fresh request completes in background:
```dart
.cacheCallback((SchemeDetailsModel cached) {
  setState(() => _schemes = cached.data);
})
```

### Special token override
Pass `.specialToken(token)` to temporarily override the stored `accessToken` — used by token renewal endpoints that authenticate with the `refreshToken`:
```dart
.specialToken(Preferences().refreshToken.getOrDefault())
```

### Error normalisation
All catch blocks should call `getErrorFromException2(e)` to normalise to `ErrorException` before propagating:
```dart
} catch (e) {
  throw getErrorFromException2(e, key: 'MyFeature');
}
```

---

## 16. Gotchas & Anti-Patterns

**1. Calling `DioImpl()` before `DioImpl.init()`**
```dart
// WRONG — LateInitializationError at runtime
DioImpl().callApiWithDioClient(...)

// CORRECT — init() must be called once in main()
DioImpl.init(cacheManager: ..., tokenManager: ..., urlsShouldNotFire401: {...});
// Then anywhere:
DioImpl().callApiWithDioClient(...)
```

**2. Hardcoding HTTP headers manually**
```dart
// WRONG — bypasses header system, misses token injection
dio.options.headers['Authorization'] = 'Bearer $token';

// CORRECT — use ApiRequestBuilder; DioImpl + ApiInterceptor handle headers
ApiRequestBuilder<T>().isTokenRequired(true)...build()
```

**3. Constructing Protobuf responses with `new` keyword directly**
```dart
// WRONG — Protobuf generated classes are NOT value types; pass instance to callApiWithDioClient
final res = GeneratePasswordResponseV2();  // OK as placeholder
res.someField = ...;  // DO NOT pre-populate — handleResponse fills it via unpackInto

// CORRECT — pass a fresh empty instance
DioImpl().callApiWithDioClient(request, GeneratePasswordResponseV2())
```

**4. Using `ApiIdentifier.unknown` for typed endpoints**
`unknown` skips base URL prepending. Only use it when the full URL is already absolute in `.url(...)`.

**5. Missing `urlsShouldNotFire401` for renewal endpoints**
Any endpoint that authenticates using the `refreshToken` must be in `urlsShouldNotFire401`. Omitting it causes `DioImpl` to call `renewToken()` on a 401 from the renewal endpoint itself — infinite recursion.

**6. Calling `SharedPreferencesProvider.instance` in static context before `init()`**
Static initialization of `Preferences` fields happens at class load time. If any static field reads `SharedPreferencesProvider.instance` before `init()` completes, an `AssertionError` is thrown. Always await `SharedPreferencesProvider.init()` before any `Preferences` access.

**7. `JsonMessageResponse.fromJson` does not throw on missing fields**
It uses lenient parsing — missing keys default to `null`/empty. Validate required fields in the caller after receiving the response object.

**8. `LoggingInterceptor` with `responseBody: true` in production**
Response bodies can contain sensitive financial data. The parameter defaults to `false`. Never set it to `true` outside a local debug build.

**9. `CacheManager.splitIfPossible` normalises keys by stripping the domain**
Cache lookups use the path portion of the URL only. Two different base URLs pointing to the same path will collide in cache. When using multiple `ApiIdentifier` values for the same path, explicitly disable cache with `.cacheAvailable(false)`.

**10. `ApiStatus.fromStatus` throws `FlutterError` on unrecognised values**
If the backend returns a status string not in `{"Success", "Failed", "Failure"}`, `fromJson` will throw. Guard with a try/catch around `callApiWithDioClient` in all feature layers.
