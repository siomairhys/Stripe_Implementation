import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:html' as web;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

mixin StripService {
  Future<Map<String, dynamic>> createPaymentIntent({
    required String amount,
  }) async {
    try {
      // We can instead use a more secure way to handle the secret key, such as environment variables or a backend service.
      final url = Uri.parse("https://api.stripe.com/v1/payment_intents");

      final response = await http.post(
        url,
        headers: {
          'Authorization':
              'Bearer YOUR_STRIPE_SECRET_KEY_HERE', // Replace with your actual secret key
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': amount,
          'currency': "usd",
          'automatic_payment_methods[enabled]': 'true',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        log("Failed: ${response.body}");
        throw Exception("Failed to create PaymentIntent");
      }
    } catch (e) {
      log("Error: $e");
      rethrow;
    }
  }

  // ignore: non_constant_identifier_names
  Future<bool> checkPaymentStatus({required String payment_intent_id}) async {
    try {
      final url = Uri.parse(
          "https://api.stripe.com/v1/payment_intents/$payment_intent_id");

      final response = await http.get(
        url,
        headers: {
          'Authorization':
              'Bearer YOUR_STRIPE_SECRET_KEY_HERE', // Replace with your actual secret key
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> result = jsonDecode(response.body);
        if (result['status'] == 'succeeded') {
          log("Payment succeeded!");
          return true;
        } else {
          log("Payment status: ${result['status']}");
          return false;
        }
      } else {
        log("Failed: ${response.body}");
        throw Exception("Failed to check payment status");
      }
    } catch (e) {
      log("Error: $e");
      rethrow;
    }
  }

  Future<String> makePaymentService(BuildContext context, String amount) async {
    final intent = await createPaymentIntent(amount: amount);
    if (intent.isEmpty) {
      log("Failed to create payment intent");
      return "";
    }
    final clientSecret = intent['client_secret'];
    final paymentIntentId = intent['id'];
    const stripePublishableKey =
        "YOUR_STRIPE_PUBLISHABLE_KEY_HERE"; // Replace with your actual publishable key
    const stripeWebview =
        "stripe/stripe_webview.html"; // Use relative path for Flutter web assets
    final viewId =
        'stripe-payment-view-${DateTime.now().millisecondsSinceEpoch}';
    ui.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
      final iframe = web.IFrameElement()
        ..src =
            '$stripeWebview?client_secret=$clientSecret&amount=$amount&publishable_key=$stripePublishableKey'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });

    final completer = Completer<String>();
    late web.EventListener listener;
    listener = (web.Event event) {
      if (event is web.MessageEvent) {
        if (event.data.toString() == "success") {
          Navigator.of(context).pop();
          log("Payment successful!");
          completer.complete(paymentIntentId);
          web.window.removeEventListener('message', listener);
        } else if (event.data.toString() == "fail" || event.data.toString() == "cancel") {
          Navigator.of(context).pop();
          log("Payment failed or cancelled!");
          completer.complete("");
          web.window.removeEventListener('message', listener);
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
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        Navigator.of(context).pop();
                        completer.complete("");
                        web.window.removeEventListener('message', listener);
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Stripe Payment",
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
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(20)),
                  child: HtmlElementView(viewType: viewId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return await completer.future;
  }
}
