# Flutter Web Stripe Integration

This Flutter web application demonstrates integration with Stripe for both one-time payments and recurring subscriptions.

## Features

- **One-time Payments**: Complete payment processing using Stripe Payment Intents
- **Recurring Subscriptions**: Two approaches for subscription management:
  - Setup Intent approach (recommended for better UX)
  - Direct subscription creation with payment confirmation
- **Web Integration**: Uses iframe-based Stripe Elements for secure payment processing
- **Widget Safety**: Includes proper lifecycle management to prevent widget disposal errors

## Setup Instructions

### 1. API Keys Configuration

Before running the application, you need to configure your Stripe API keys:

1. Create a `.env` file in the root directory (already included in .gitignore)
2. Add your Stripe keys to the `.env` file:
   ```
   STRIPE_SECRET_KEY=sk_test_your_secret_key_here
   STRIPE_PUBLISHABLE_KEY=pk_test_your_publishable_key_here
   ```

3. Update the following files with your actual API keys:
   - `lib/subscription_service.dart`: Replace `YOUR_STRIPE_SECRET_KEY_HERE` with your secret key
   - `lib/web_strip_service.dart`: Replace both `YOUR_STRIPE_SECRET_KEY_HERE` and `YOUR_STRIPE_PUBLISHABLE_KEY_HERE`

### 2. Stripe Dashboard Setup

1. Create a Stripe account at https://stripe.com
2. Get your test API keys from the Stripe Dashboard
3. Create a price/product for subscription testing (recommended: monthly $10 subscription)
4. Update the `priceId` in the subscription service calls if needed

### 3. Running the Application

```bash
flutter run -d chrome
```

## File Structure

- `lib/main.dart`: Main application with test buttons for different payment flows
- `lib/web_strip_service.dart`: One-time payment service using Payment Intents
- `lib/subscription_service.dart`: Subscription service with dual approaches
- `web/stripe/stripe_webview.html`: HTML form for one-time payments
- `web/stripe/subscription_webview.html`: HTML form for subscription setup
- `.env`: Environment variables for API keys (not tracked in git)

## Security Notes

- **Never commit API keys to version control**
- All API keys have been replaced with placeholders in the code
- Use environment variables or secure backend services for production
- The `.env` file is excluded from git via `.gitignore`

## Usage

The application provides several test buttons:

1. **Make Payment**: Tests one-time payment flow
2. **Subscribe Monthly (Setup Intent)**: Recommended subscription approach
3. **Subscribe Monthly (Original)**: Alternative subscription approach
4. **Test HTML**: Direct HTML form testing

## Troubleshooting

- Ensure all API keys are correctly configured
- Check browser console for any iframe loading errors
- Verify Stripe webhook endpoints if using production mode
- Test with Stripe's test card numbers: `4242 4242 4242 4242`

## Development Notes

- Widget lifecycle safety implemented with completion guards and context.mounted checks
- Dual subscription approaches for different use cases
- Comprehensive error handling and logging
- Clean separation between payment and subscription services
