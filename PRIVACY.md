# Privacy Policy

This application includes _opt-in_ error and performance reporting powered by
[Sentry](https://sentry.io), an open-source error monitoring service.

## What We Collect

If you choose to opt in to error reporting, we may collect the following
information when an unhandled exception occurs:

- Dart tracebacks and exception details
- Application version
- Dart/Flutter version
- Operating system name (e.g. "iOS" or "Android") and version
- A randomly generated install identifier as described in the [Sentry documentation](https://docs.sentry.io/security-legal-pii/security/mobile-privacy/#does-sentry-use-the-device-id-to-identify-a-user)
- Whether the application is a development version or a release version
- Application logs related to the app functionality (e.g. "set theme mode", "failed sync phase")

> We make every effort to strip potentially sensitive information, such as server URIs, before sending as well as ingesting.

## What We Don’t Collect

We **do not collect**:

- Names, email addresses, or any personal identifiers
- Documents, or data files
- IP addresses (Sentry is configured to avoid storing PII)
- Server URIs (these are stripped before sending)

## When We Collect It

Error reporting is **opt-in only**. No data is sent without your consent.

On first launch, you'll be asked whether you'd like to send crash reports.
Your response is stored locally in a configuration file. If you answer "Yes",
the application will send error reports and logs to Sentry when an unhandled exception
occurs.

## Opting out

You can change your preference at any time in the application's settings.

## Transparency

The complete error reporting logic is open source and viewable at:

<https://github.com/rodonisi/kover/blob/main/lib/utils/sentry.dart>
<https://github.com/rodonisi/kover/blob/main/lib/utils/logging.dart>
<https://github.com/rodonisi/kover/blob/main/lib/riverpod/repository/sentry_repository.dart>

## Data Retention

Collected data may be stored by Sentry for up to **90 days** for debugging and
quality improvement purposes.

## Legal Basis for Processing (GDPR/UK GDPR)

For users in the EU or UK, the legal basis for collecting crash reports is
**your explicit consent** under Article 6(1)(a) of the GDPR. No data is
collected unless you opt in.

## Your Rights (for EU/UK Users)

Under the GDPR, you have the right to access, delete, or object to the
processing of your personal data.

Note, we **do not collect any data that can be used to identify you**, and
therefore have no way to link error reports to specific individuals. As a
result, we are **unable to fulfill individual access or deletion requests**
because we cannot associate any data with you.

## Third-party Services (Sentry)

Error reports are sent to:

**Sentry**  
Functional Software, Inc.
45 Fremont Street, 8th Floor
San Francisco, CA 94105
Privacy Policy: [https://sentry.io/privacy/](https://sentry.io/privacy/)  
Data Processing Agreement: [https://sentry.io/legal/dpa/](https://sentry.io/legal/dpa/)

## Contact

For any questions or concerns about this policy, feel free to [open an
issue](https://github.com/rodonisi/kover/issues/new) on our GitHub repository.

---

_Last updated: 2026-06-19_
