import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:craig_o_clean/providers/entitlement_provider.dart';

/// Provider for the deep link service
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService(ref);
});

/// Deep link event types
enum DeepLinkEventType {
  paymentSuccess,
  paymentCancelled,
  billingComplete,
  navigate,
  unknown,
}

/// Deep link event
class DeepLinkEvent {
  const DeepLinkEvent({
    required this.type,
    this.sessionId,
    this.route,
    this.parameters,
  });

  final DeepLinkEventType type;
  final String? sessionId;
  final String? route;
  final Map<String, String>? parameters;
}

/// Provider for deep link events stream
final deepLinkEventsProvider = StreamProvider<DeepLinkEvent>((ref) {
  final service = ref.watch(deepLinkServiceProvider);
  return service.events;
});

/// Service for handling deep links
class DeepLinkService {
  DeepLinkService(this._ref);

  final Ref _ref;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  final _eventsController = StreamController<DeepLinkEvent>.broadcast();

  /// Stream of deep link events
  Stream<DeepLinkEvent> get events => _eventsController.stream;

  /// Initialize the deep link service
  Future<void> initialize() async {
    try {
      // Handle initial link if app was launched from a deep link
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }

      // Listen for incoming links while app is running
      _subscription = _appLinks.uriLinkStream.listen(
        _handleUri,
        onError: (error) {
          debugPrint('Deep link error: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to initialize deep links: $e');
    }
  }

  /// Handle an incoming URI
  void _handleUri(Uri uri) {
    debugPrint('Received deep link: $uri');

    final event = _parseUri(uri);
    _eventsController.add(event);

    // Process the event
    _processEvent(event);
  }

  /// Parse URI into a deep link event
  DeepLinkEvent _parseUri(Uri uri) {
    // Expected URIs:
    // craigoclean://payment-success?session_id=xxx
    // craigoclean://payment-cancelled
    // craigoclean://billing-complete
    // craigoclean://navigate?route=xxx

    final host = uri.host;
    final queryParams = uri.queryParameters;

    switch (host) {
      case 'payment-success':
        return DeepLinkEvent(
          type: DeepLinkEventType.paymentSuccess,
          sessionId: queryParams['session_id'],
          parameters: queryParams,
        );

      case 'payment-cancelled':
        return DeepLinkEvent(
          type: DeepLinkEventType.paymentCancelled,
          parameters: queryParams,
        );

      case 'billing-complete':
        return DeepLinkEvent(
          type: DeepLinkEventType.billingComplete,
          parameters: queryParams,
        );

      case 'navigate':
        return DeepLinkEvent(
          type: DeepLinkEventType.navigate,
          route: queryParams['route'],
          parameters: queryParams,
        );

      default:
        return DeepLinkEvent(
          type: DeepLinkEventType.unknown,
          parameters: queryParams,
        );
    }
  }

  /// Process a deep link event
  Future<void> _processEvent(DeepLinkEvent event) async {
    switch (event.type) {
      case DeepLinkEventType.paymentSuccess:
        if (event.sessionId != null) {
          await _handlePaymentSuccess(event.sessionId!);
        }

      case DeepLinkEventType.paymentCancelled:
        debugPrint('Payment was cancelled');

      case DeepLinkEventType.billingComplete:
        // Refresh entitlement after billing portal visit
        await _ref.read(entitlementProvider.notifier).verifyEntitlement();

      case DeepLinkEventType.navigate:
        // Navigation will be handled by the UI
        break;

      case DeepLinkEventType.unknown:
        debugPrint('Unknown deep link type');
    }
  }

  /// Handle successful payment
  Future<void> _handlePaymentSuccess(String sessionId) async {
    try {
      await _ref
          .read(entitlementProvider.notifier)
          .handlePaymentSuccess(sessionId);
    } catch (e) {
      debugPrint('Failed to handle payment success: $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    _subscription?.cancel();
    _eventsController.close();
  }
}
