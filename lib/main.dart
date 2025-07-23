import 'dart:developer';
import 'dart:html' as web;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'web_strip_service.dart';        // One-time payments
import 'subscription_service.dart';      // Recurring subscriptions

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stripe Web Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(title: 'Stripe Web Example'),
    );
  }
}

class MyHomePage extends StatelessWidget with StripService, SubscriptionService {
  MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: Column(
        children: [
          // One-time payment button
          ElevatedButton(
            onPressed: () async {
              // This uses web_strip_service.dart → stripe_webview.html
              String paymentID = await makePaymentService(context, "5000");
              if (paymentID.isEmpty) {
                log('Payment failed, please try again');
              } else {
                log('Payment successful, ID: $paymentID');
                bool paymentSuccess =
                    await checkPaymentStatus(payment_intent_id: paymentID);
                if (paymentSuccess) {
                  log('Payment status confirmed');
                } else {
                  log('Payment status could not be confirmed');
                }
              }
            },
            child: const Text('Pay \$50.00 Once'),
          ),
          
          const SizedBox(height: 15),
          // Subscription button  
          ElevatedButton(
            onPressed: () async {
              log('🔄 Starting subscription process...');
              try {
                // Try the alternative approach first
                String subscriptionId = await createSubscriptionServiceWithSetupIntent(
                  context,
                  email: "shoppefreeship12@gmail.com",
                  priceId: "price_1RnrUwPrXFi8coEY6iqUv2jL",
                );
                if (subscriptionId.isEmpty) {
                  log('Subscription setup failed');
                } else {
                  log('Subscription created successfully: $subscriptionId');
                }
              } catch (e) {
                log('Subscription error: $e');
              }
              log('Subscription process completed');
            },
            child: const Text('Subscribe Monthly (Setup Intent)'),
          ),
          
          const SizedBox(height: 15),
          // Original subscription button for comparison
          ElevatedButton(
            onPressed: () async {
              log('🔄 Starting original subscription process...');
              try {
                // This uses subscription_service.dart → subscription_webview.html
                String subscriptionId = await createSubscriptionService(
                  context,
                  email: "shoppefreeship12@gmail.com",
                  priceId: "price_1RnrUwPrXFi8coEY6iqUv2jL",
                );
                if (subscriptionId.isEmpty) {
                  log('Original subscription setup failed');
                } else {
                  log('Original subscription created successfully: $subscriptionId');
                }
              } catch (e) {
                log('Original subscription error: $e');
              }
              log('Original subscription process completed');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            child: const Text('Subscribe Monthly (Original)'),
          ),
          
          const SizedBox(height: 15),
          // Test HTML loading button
          ElevatedButton(
            onPressed: () {
              log('🧪 Testing HTML file loading...');
              final testViewId = 'test-html-${DateTime.now().millisecondsSinceEpoch}';
              
              // Register the test view
              ui.platformViewRegistry.registerViewFactory(
                testViewId,
                (int viewId) {
                  final iframe = web.IFrameElement()
                    ..src = 'stripe/subscription_webview.html?test=true'
                    ..style.border = 'none'
                    ..style.width = '100%'
                    ..style.height = '100%';
                  return iframe;
                },
              );
              
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Test HTML Loading'),
                  content: SizedBox(
                    width: 400,
                    height: 300,
                    child: HtmlElementView(viewType: testViewId),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Test HTML'),
          ),
          
          const SizedBox(height: 15),
          // Test dialog button
          ElevatedButton(
            onPressed: () {
              log('🧪 Testing dialog...');
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Test Dialog'),
                  content: const Text('If you see this, dialogs work!'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Test Dialog'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          log('Initializing payment...');
          String paymentID = await makePaymentService(context, "5000");
          if (paymentID.isEmpty) {
            log('Payment failed, please try again');
          } else {
            log('Payment successful, ID: $paymentID');
            bool paymentSuccess =
                await checkPaymentStatus(payment_intent_id: paymentID);
            if (paymentSuccess) {
              log('Payment status confirmed');
            } else {
              log('Payment status could not be confirmed');
            }
          }
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
