/// The privacy policy and terms of use shown inside the app. The privacy
/// policy matches store/privacy-policy.html.
library;

typedef LegalSection = (String heading, String body);

const String privacyUpdated = 'Last updated: 11 October 2026';

const List<LegalSection> privacySections = [
  (
    'Summary',
    'Trippi keeps your trips on your phone. We have no server and no '
        'accounts, and we never see the names, amounts or notes you enter.',
  ),
  (
    'Data stored on your phone',
    'Trips, participant names, expenses, payments, categories and settings '
        'are stored only in the app on your phone. Uninstalling the app '
        'deletes them. If you use Back up (Premium), the backup file goes '
        'wherever you choose to save or send it.',
  ),
  (
    'Exchange rates',
    'To show exchange rates, the app asks the Frankfurter service '
        '(api.frankfurter.dev, or api.frankfurter.app as a fallback) for '
        'reference rates. These requests contain only currency codes and '
        'dates, never your trips or amounts. Like any internet request, they '
        'reveal your IP address to that service.',
  ),
  (
    'Advertising (free plan only)',
    'On the free plan the app shows ads from Google AdMob. The Google Mobile '
        'Ads SDK collects and shares with Google your IP address (which gives '
        'an approximate location), advertising and app set identifiers, ad '
        'and app interactions, and diagnostic information. Google uses this '
        'to show and measure ads, for analytics, and to prevent fraud; it is '
        'encrypted in transit. In the European Economic Area, the UK and '
        'Switzerland, you are asked for consent first and can change your '
        'choice at any time under Settings > Privacy options. On iPhone, ads '
        'are always non-personalised and the app never asks to track you. '
        "Google's privacy policy: https://policies.google.com/privacy. "
        'Premium subscribers see no ads, and no ad requests are made for them.',
  ),
  (
    'Purchases',
    'Subscriptions are handled by Apple (App Store) or Google (Google '
        'Play). The app never sees your payment details. It only asks the '
        'store whether your subscription is active.',
  ),
  (
    'Children',
    'Trippi is meant for a general audience and is not directed at children '
        'under 13.',
  ),
  (
    'Your choices',
    'You can delete any trip in the app, or uninstall the app to delete '
        'everything. Because we hold no data about you on any server, there '
        'is nothing for us to delete or export on request.',
  ),
  (
    'Changes',
    'If this policy changes, the new version will be published at the same '
        'address and in the app, with a new date.',
  ),
  (
    'Contact',
    "Questions about privacy: use the contact email on the app's store "
        'listing.',
  ),
];

const List<LegalSection> termsSections = [
  (
    'What Trippi does',
    'Trippi helps a group record shared travel costs, convert currencies and '
        'work out who owes whom. It is a calculator for your own records, not '
        'a payment or banking service: no money moves through the app.',
  ),
  (
    'Your data',
    'Everything you enter stays on your phone. You are responsible for '
        'keeping your own backups. Uninstalling the app deletes your data '
        'unless you saved a backup file first.',
  ),
  (
    'Premium subscription',
    'Trippi Premium is a monthly subscription billed by the App Store or '
        'Google Play. If a free trial is offered, it is shown with its end '
        'date before you subscribe, and you are charged when it ends unless '
        'you cancel before then. The subscription renews automatically each '
        'month until you cancel it in your App Store or Google Play '
        'subscription settings. Cancelling stops the next renewal; Premium '
        'stays active until the end of the period you paid for. Refunds are '
        'handled by Apple or Google under their rules.',
  ),
  (
    'Premium Pass',
    'Watching an optional video can give you a free 24-hour Premium Pass. It '
        'unlocks advanced stats, PDF and Excel export, historical rates and '
        'themes for 24 hours. It does not remove ads or raise the free trip '
        'and participant limits.',
  ),
  (
    'No warranty',
    'Calculations, rounding and exchange rates are provided as they are, '
        'without warranty. Exchange rates are European Central Bank '
        'reference rates and may differ from the rates your bank or card '
        'used. Please check important amounts before you pay anyone.',
  ),
  ('Changes', 'These terms may be updated with new versions of the app.'),
];
