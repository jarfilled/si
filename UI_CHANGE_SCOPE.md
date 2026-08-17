# UI refresh scope

This branch intentionally modifies the existing UI files instead of introducing a parallel UI architecture.

Changed and reviewed screens:
- `lib/UI/onBoarding.dart`
- `lib/UI/login_page.dart`
- `lib/UI/signup_page.dart`
- `lib/UI/calibration_screen.dart`
- `lib/UI/dashboard.dart`
- `lib/UI/posture_analysis_page.dart`
- `lib/UI/health_summary_page.dart`
- `lib/UI/profile_page.dart`
- `lib/UI/settings_page.dart`
- `lib/UI/exercise_center_page.dart`
- `lib/UI/splashScreen.dart`

The profile page keeps a single settings action and concentrates account information, calibration, exercise access, and health information without duplicating the dashboard's daily-support widgets.

The dashboard uses an interactive water tracker and a daily social-connection reminder rather than duplicating a mood quiz. The social reminder is intentionally lightweight: it encourages the user to spend time with a friend or someone close and lets them mark the action as completed for the day.

Responsive layouts are used throughout the refreshed screens so cards, metrics, actions, and text can reflow or stack on narrower devices instead of relying on fixed horizontal sizes.

The calibration page supports recalibration for already-calibrated users and keeps the existing personalized posture-calibration flow.

The health summary now also adapts its metric cards and score summary on narrow screens to avoid horizontal overflow.