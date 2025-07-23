import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:html' as web;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

mixin SubscriptionService {
  // Create a customer
  Future<Map<String, dynamic>> createCustomer({
    required String email,
    String? name,
  }) async {
    try {
      final url = Uri.parse("https://api.stripe.com/v1/customers");
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer YOUR_STRIPE_SECRET_KEY_HERE',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'email': email,
          if (name != null) 'name': name,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        log("Failed to create customer: ${response.body}");
        throw Exception("Failed to create customer");
      }
    } catch (e) {
      log("Error creating customer: $e");
      rethrow;
    }
  }

  // Create a setup intent for subscription payment method
  Future<Map<String, dynamic>> createSetupIntent({
    required String customerId,
  }) async {
    try {
      final url = Uri.parse("https://api.stripe.com/v1/setup_intents");
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer YOUR_STRIPE_SECRET_KEY_HERE',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'customer': customerId,
          'usage': 'off_session',
          'payment_method_types[]': 'card',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        log("Failed to create setup intent: ${response.body}");
        throw Exception("Failed to create setup intent");
      }
    } catch (e) {
      log("Error creating setup intent: $e");
      rethrow;
    }
  }

  // Create subscription with setup intent for future payments
  Future<Map<String, dynamic>> createSubscription({
    required String customerId,
    required String priceId, // Stripe Price ID for your subscription plan
  }) async {
    try {
      final url = Uri.parse("https://api.stripe.com/v1/subscriptions");
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer YOUR_STRIPE_SECRET_KEY_HERE',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'customer': customerId,
          'items[0][price]': priceId,
          'payment_behavior': 'default_incomplete',
          'payment_settings[save_default_payment_method]': 'on_subscription',
          'expand[0]': 'latest_invoice.payment_intent',
          'expand[1]': 'pending_setup_intent',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        log("Failed to create subscription: ${response.body}");
        throw Exception("Failed to create subscription");
      }
    } catch (e) {
      log("Error creating subscription: $e");
      rethrow;
    }
  }

  // Check subscription status
  Future<Map<String, dynamic>> getSubscription({
    required String subscriptionId,
  }) async {
    try {
      final url = Uri.parse("https://api.stripe.com/v1/subscriptions/$subscriptionId");
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer YOUR_STRIPE_SECRET_KEY_HERE',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        log("Failed to get subscription: ${response.body}");
        throw Exception("Failed to get subscription");
      }
    } catch (e) {
      log("Error getting subscription: $e");
      rethrow;
    }
  }

  // Cancel subscription
  Future<bool> cancelSubscription({
    required String subscriptionId,
    bool cancelAtPeriodEnd = true,
  }) async {
    try {
      final url = Uri.parse("https://api.stripe.com/v1/subscriptions/$subscriptionId");
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer YOUR_STRIPE_SECRET_KEY_HERE',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          if (cancelAtPeriodEnd)
            'cancel_at_period_end': 'true'
          else
            'cancel_at_period_end': 'false',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      log("Error canceling subscription: $e");
      return false;
    }
  }

  // Alternative: Main subscription service method using Setup Intent first
  Future<String> createSubscriptionServiceWithSetupIntent(
    BuildContext context, {
    required String email,
    required String priceId,
    String? customerName,
  }) async {
    try {
      log('Alternative Step 1: Creating customer...');
      // Step 1: Create customer
      final customer = await createCustomer(email: email, name: customerName);
      final customerId = customer['id'];
      log('Customer created: $customerId');
      
      log('Alternative Step 2: Creating setup intent...');
      // Step 2: Create setup intent for payment method collection
      final setupIntent = await createSetupIntent(customerId: customerId);
      final clientSecret = setupIntent['client_secret'];
      log('Setup intent created with client_secret: ${clientSecret.substring(0, 20)}...');
      
      // Step 3: Show payment form for payment method setup
      const stripePublishableKey = "YOUR_STRIPE_PUBLISHABLE_KEY_HERE";
      const stripeWebview = "stripe/subscription_webview.html";
      
      log('Alternative Step 3: Building iframe URL...');
      final iframeUrl = '$stripeWebview?client_secret=$clientSecret&publishable_key=$stripePublishableKey&setup_intent_id=${setupIntent['id']}';
      log('Iframe URL: $iframeUrl');
      
      final viewId = 'stripe-subscription-view-${DateTime.now().millisecondsSinceEpoch}';
      
      log('Alternative Step 4: Registering iframe...');
      ui.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
        final iframe = web.IFrameElement()
          ..src = iframeUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
        return iframe;
      });

      final completer = Completer<String>();
      late web.EventListener listener;
      bool isCompleted = false;
      
      listener = (web.Event event) {
        if (event is web.MessageEvent && !isCompleted) {
          if (event.data.toString() == "success") {
            isCompleted = true;
            web.window.removeEventListener('message', listener);
            log("Setup intent completed successfully!");
            
            // Safely close dialog
            try {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            } catch (e) {
              log("Error closing dialog: $e");
            }
            
            // After setup intent succeeds, create the subscription
            createSubscription(customerId: customerId, priceId: priceId).then((subscription) {
              if (!completer.isCompleted) {
                completer.complete(subscription['id']);
              }
            }).catchError((error) {
              log("Failed to create subscription after setup: $error");
              if (!completer.isCompleted) {
                completer.complete("");
              }
            });
          } else if (event.data.toString() == "fail" || event.data.toString() == "cancel") {
            isCompleted = true;
            web.window.removeEventListener('message', listener);
            log("Setup intent failed or cancelled!");
            
            // Safely close dialog
            try {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            } catch (e) {
              log("Error closing dialog: $e");
            }
            
            if (!completer.isCompleted) {
              completer.complete("");
            }
          }
        }
      };
      
      web.window.addEventListener('message', listener);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SizedBox(
            width: 400,
            height: 650,
            child: Column(
              children: [
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          if (!isCompleted) {
                            isCompleted = true;
                            web.window.removeEventListener('message', listener);
                            try {
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            } catch (e) {
                              log("Error closing dialog manually: $e");
                            }
                            if (!completer.isCompleted) {
                              completer.complete("");
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Setup Payment Method",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    child: HtmlElementView(viewType: viewId),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      
      return await completer.future;
    } catch (e) {
      log("Error in alternative subscription service: $e");
      return "";
    }
  }

  // Main subscription service method
  Future<String> createSubscriptionService(
    BuildContext context, {
    required String email,
    required String priceId,
    String? customerName,
  }) async {
    try {
      log('Step 1: Creating customer...');
      // Step 1: Create customer
      final customer = await createCustomer(email: email, name: customerName);
      final customerId = customer['id'];
      log('Customer created: $customerId');
      
      log('Step 2: Creating subscription...');
      // Step 2: Create subscription
      final subscription = await createSubscription(
        customerId: customerId,
        priceId: priceId,
      );
      final subscriptionId = subscription['id']; // This will be: sub_1RnrmvPrXFi8coEYrkDkw09X
      log('Subscription created: $subscriptionId');
      log('Subscription response structure: ${subscription.keys.toList()}');
      
      log('Step 3: Extracting client secret...');
      log('Full subscription response keys: ${subscription.keys.toList()}');
      
      String? clientSecret;
      
      // Try to get client_secret from payment_intent first
      if (subscription['latest_invoice'] != null) {
        final latestInvoice = subscription['latest_invoice'];
        log('Latest invoice keys: ${latestInvoice.keys.toList()}');
        
        if (latestInvoice['payment_intent'] != null) {
          final paymentIntent = latestInvoice['payment_intent'];
          log('Payment intent keys: ${paymentIntent.keys.toList()}');
          clientSecret = paymentIntent['client_secret'];
          log('Client secret from payment_intent: ${clientSecret?.substring(0, 20)}...');
        }
      }
      
      // If no payment_intent, try setup_intent for subscription setup
      if (clientSecret == null && subscription['pending_setup_intent'] != null) {
        final setupIntent = subscription['pending_setup_intent'];
        log('Setup intent keys: ${setupIntent.keys.toList()}');
        clientSecret = setupIntent['client_secret'];
        log('Client secret from setup_intent: ${clientSecret?.substring(0, 20)}...');
      } else if (clientSecret == null) {
        log('Checking if pending_setup_intent exists: ${subscription.containsKey('pending_setup_intent')}');
        log('pending_setup_intent value: ${subscription['pending_setup_intent']}');
      }
      
      if (clientSecret == null) {
        log('No client_secret found in payment_intent or setup_intent');
        throw Exception('No client_secret found');
      }
      
      log('Final client secret: ${clientSecret.substring(0, 20)}...');
      
      // Step 3: Show payment form for initial setup
      const stripePublishableKey = "YOUR_STRIPE_PUBLISHABLE_KEY_HERE";
      const stripeWebview = "stripe/subscription_webview.html"; // Use relative path for Flutter web assets (same as stripe_webview.html)
      
      log('Step 4: Building iframe URL...');
      final iframeUrl = '$stripeWebview?client_secret=$clientSecret&publishable_key=$stripePublishableKey&subscription_id=$subscriptionId';
      log('Iframe URL: $iframeUrl');
      log('URL breakdown:');
      log('  - Base URL: $stripeWebview');
      log('  - Client Secret: ${clientSecret.substring(0, 30)}...');
      log('  - Publishable Key: ${stripePublishableKey.substring(0, 30)}...');
      log('  - Subscription ID: $subscriptionId');
      
      final viewId = 'stripe-subscription-view-${DateTime.now().millisecondsSinceEpoch}';
      
      log('Step 5: Registering iframe...');
      ui.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
        log('Creating iframe element...');
        log('Final iframe src: $iframeUrl');
        final iframe = web.IFrameElement()
          ..src = iframeUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
        
        // Add error handling for iframe
        iframe.onLoad.listen((event) {
          log('Iframe loaded successfully');
        });
        
        iframe.onError.listen((event) {
          log('Iframe failed to load: $event');
        });
        
        log('Iframe element created, src set to: ${iframe.src}');
        return iframe;
      });

      final completer = Completer<String>();
      late web.EventListener listener;
      bool isCompleted = false;
      
      listener = (web.Event event) {
        if (event is web.MessageEvent && !isCompleted) {
          if (event.data.toString() == "success") {
            isCompleted = true;
            web.window.removeEventListener('message', listener);
            log("Subscription created successfully!");
            
            try {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            } catch (e) {
              log("Error closing dialog: $e");
            }
            
            if (!completer.isCompleted) {
              completer.complete(subscriptionId);
            }
          } else if (event.data.toString() == "fail" || event.data.toString() == "cancel") {
            isCompleted = true;
            web.window.removeEventListener('message', listener);
            log("Subscription setup failed or cancelled!");
            
            try {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            } catch (e) {
              log("Error closing dialog: $e");
            }
            
            if (!completer.isCompleted) {
              completer.complete("");
            }
          }
        }
      };
      
      web.window.addEventListener('message', listener);

      log('Step 6: Showing dialog...');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SizedBox(
            width: 400,
            height: 650,
            child: Column(
              children: [
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          if (!isCompleted) {
                            isCompleted = true;
                            web.window.removeEventListener('message', listener);
                            log('Dialog closed by user');
                            try {
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            } catch (e) {
                              log("Error closing dialog manually: $e");
                            }
                            if (!completer.isCompleted) {
                              completer.complete("");
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Setup Subscription",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    child: HtmlElementView(viewType: viewId),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      log('Dialog shown successfully');
      
      return await completer.future;
    } catch (e) {
      log("Error in subscription service: $e");
      return "";
    }
  }
}
