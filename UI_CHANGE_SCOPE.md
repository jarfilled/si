# UI refresh scope

This branch intentionally modifies the existing UI files instead of introducing a parallel UI architecture.

Changed screens:
- `lib/UI/onBoarding.dart`
- `lib/UI/login_page.dart`
- `lib/UI/signup_page.dart`
- `lib/UI/calibration_screen.dart`
- `lib/UI/profile_page.dart`

The profile page now keeps one settings action and exposes calibration, exercise, water, mood, and health-summary actions in the existing ProfilePage.

The calibration page no longer redirects already-calibrated users away from recalibration.
