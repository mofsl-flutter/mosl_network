# base_network

A Dart package providing a robust, extensible network client built on top of Dio, with support for:

- HTTP/2 and Brotli compression
- Request/response logging
- Firebase Performance monitoring
- Sentry error tracking
- Caching and retry logic
- Customizable interceptors
- Authentication and session management

## Features

- **Dio-based HTTP client** with advanced configuration
- **Interceptor support** for logging, caching, and monitoring
- **Firebase Performance** integration via `firebase_performance_dio`
- **Sentry** integration for error reporting
- **Retry logic** for network resilience
- **Custom error handling** and session management
- Supports methods like GET, POST, UPLOAD, DOWNLOAD

## Getting Started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  base_network:
    path: packages/base_network


Extend the `BaseNetworkClient` class to create your own network client:

then give your network client a cachemanagr also a token manager

the token manager object to be created with extending base_token_manager

and impl the methods and provide the response it expects 

now once you got the response in your network client you can comiple it to the userdefined classes 

error handling is alos done there refer DioImpl for more details




the cache saving part is done in the cache manager

and getting the response from the cache and passing to ui is don in base_interceptor also its done via callback 


The error handling done with ErrorException class which is a custom class that extends Exception 

