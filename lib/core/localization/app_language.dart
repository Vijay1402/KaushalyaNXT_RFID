import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _languagePreferenceKey = 'app_language_code';

class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  final String code;
  final String name;
  final String nativeName;

  Locale get locale => Locale(code);
}

const supportedAppLanguages = <AppLanguage>[
  AppLanguage(code: 'en', name: 'English', nativeName: 'English'),
  AppLanguage(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ'),
  AppLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
  AppLanguage(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்'),
  AppLanguage(code: 'te', name: 'Telugu', nativeName: 'తెలుగు'),
];

final appLanguageProvider =
    StateNotifierProvider<AppLanguageController, Locale>((ref) {
  return AppLanguageController();
});

class AppLanguageController extends StateNotifier<Locale> {
  AppLanguageController() : super(const Locale('en')) {
    _loadSavedLanguage();
  }

  Future<void> setLanguage(String languageCode) async {
    final language = _languageForCode(languageCode);
    state = language.locale;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePreferenceKey, language.code);
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_languagePreferenceKey);
    if (savedCode == null || savedCode.trim().isEmpty) return;

    state = _languageForCode(savedCode).locale;
  }

  AppLanguage _languageForCode(String code) {
    return supportedAppLanguages.firstWhere(
      (language) => language.code == code,
      orElse: () => supportedAppLanguages.first,
    );
  }
}

AppLanguage appLanguageForLocale(Locale locale) {
  return supportedAppLanguages.firstWhere(
    (language) => language.code == locale.languageCode,
    orElse: () => supportedAppLanguages.first,
  );
}

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  String text(String key) {
    final values = _localizedValues[locale.languageCode];
    final englishValues = _localizedValues['en'];
    final directValue = values?[key] ?? englishValues?[key];
    if (directValue != null) return directValue;

    final matchingEntry = englishValues?.entries.firstWhere(
      (entry) => entry.value == key,
      orElse: () => const MapEntry('', ''),
    );
    if (matchingEntry != null && matchingEntry.key.isNotEmpty) {
      return values?[matchingEntry.key] ?? matchingEntry.value;
    }

    return key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return supportedAppLanguages.any(
      (language) => language.code == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  String tr(String key) => AppLocalizations.of(this).text(key);
}

const _localizedValues = <String, Map<String, String>>{
  'en': {
    'profile': 'Profile',
    'notificationSettings': 'Notification Settings',
    'faqs': 'FAQs',
    'support': 'Support',
    'aboutApp': 'About App',
    'localStorage': 'Local Storage',
    'language': 'Language',
    'chooseLanguage': 'Choose Language',
    'cancel': 'Cancel',
    'personalInformation': 'Personal Information',
    'phone': 'Phone',
    'location': 'Location',
    'email': 'Email',
    'managerCode': 'Manager Code',
    'farmManager': 'Farm Manager',
    'notLinked': 'Not linked',
    'farmDetails': 'Farm Details',
    'landSize': 'Land Size',
    'totalTrees': 'Total Trees',
    'mainCrops': 'Main Crops',
    'irrigation': 'Irrigation',
    'editProfile': 'Edit Profile',
    'resetPassword': 'Reset Password',
    'logout': 'Logout',
    'home': 'Home',
    'myTrees': 'My Trees',
    'report': 'Report',
    'namaste': 'Namaste',
    'activityLog': 'Activity Log',
    'notifications': 'Notifications',
    'syncStatusPanel': 'SYNC STATUS PANEL',
    'online': 'ONLINE',
    'offline': 'OFFLINE',
    'healthy': 'Healthy',
    'needAttention': 'Need Attention',
    'humidity': 'Humidity',
    'wind': 'Wind',
    'rain': 'Rain',
    'clouds': 'Clouds',
    'currentLocation': 'Current location',
    'gettingWeather': 'Getting location and weather...',
    'weatherAfterAccess': 'Weather will appear after location access.',
    'refreshWeather': 'Refresh weather',
    'Welcome Back': 'Welcome Back',
    'Sign in with your registered email address.':
        'Sign in with your registered email address.',
    'Email Address': 'Email Address',
    'Password': 'Password',
    'Forget password?': 'Forget password?',
    'LOG IN': 'LOG IN',
    'OR': 'OR',
    "Don't have an account? ": "Don't have an account? ",
    'SIGN UP': 'SIGN UP',
    'Create Account': 'Create Account',
    'Create an account with email and password.':
        'Create an account with email and password.',
    'Full Name': 'Full Name',
    'Phone Number': 'Phone Number',
    'Farm Manager Code (Optional)': 'Farm Manager Code (Optional)',
    'Add a farm manager code only if you want to work under that manager.':
        'Add a farm manager code only if you want to work under that manager.',
    'Confirm Password': 'Confirm Password',
    'Farmer': 'Farmer',
    'Farm Manager': 'Farm Manager',
    'Your farm manager code will be generated automatically after registration.':
        'Your farm manager code will be generated automatically after registration.',
    'Already have an account? ': 'Already have an account? ',
    'LOGIN': 'LOGIN',
    'Forget Password': 'Forget Password',
    'Enter your Email to receive a password reset link':
        'Enter your Email to receive a password reset link',
    'SEND RESET LINK': 'SEND RESET LINK',
    'Back to Login': 'Back to Login',
    'Please enter email': 'Please enter email',
    'Enter valid email': 'Enter valid email',
    'Reset link sent to your email': 'Reset link sent to your email',
    'Something went wrong': 'Something went wrong',
    'Error occurred': 'Error occurred',
    'All': 'All',
    'At Risk': 'At Risk',
    'Search by Tree ID, Location...': 'Search by Tree ID, Location...',
    'Scan History': 'Scan History',
    'Farmer Issues': 'Farmer Issues',
    'Issues': 'Issues',
    'No scan history available yet.': 'No scan history available yet.',
    'No issue reports available yet.': 'No issue reports available yet.',
    'How to scan a tree?': 'How to scan a tree?',
    "Go to the dashboard and tap on 'Scan Now'. Use the camera to scan the RFID tag attached to the tree.":
        "Go to the dashboard and tap on 'Scan Now'. Use the camera to scan the RFID tag attached to the tree.",
    'How to view reports?': 'How to view reports?',
    'Navigate to the Reports tab from the bottom menu to see all your tree reports and analytics.':
        'Navigate to the Reports tab from the bottom menu to see all your tree reports and analytics.',
    'How to update profile?': 'How to update profile?',
    "Go to Profile screen and click on 'Edit Profile' to update your details.":
        "Go to Profile screen and click on 'Edit Profile' to update your details.",
    'Need Help? Contact Us': 'Need Help? Contact Us',
    'Describe your issue': 'Describe your issue',
    'Describe your issue...': 'Describe your issue...',
    'Please describe your issue': 'Please describe your issue',
    'Submitted successfully': 'Submitted successfully',
    'Submit': 'Submit',
    'My Farm': 'My Farm',
    'Analytics': 'Analytics',
    'User Management': 'User Management',
    'Add, edit, and remove users': 'Add, edit, and remove users',
    'Activity Overview': 'Activity Overview',
    'Open the admin activity overview': 'Open the admin activity overview',
    'Open your profile settings': 'Open your profile settings',
    'Sign out from admin dashboard': 'Sign out from admin dashboard',
    'Admin Alerts': 'Admin Alerts',
    'No active alerts right now.': 'No active alerts right now.',
    'Open Issues': 'Open Issues',
    'Do you want to sign out from the admin dashboard?':
        'Do you want to sign out from the admin dashboard?',
    'Total Managed Farms': 'Total Managed Farms',
    'Total Issues': 'Total Issues',
    'Critical': 'Critical',
    'Farm Directory': 'Farm Directory',
    'Issue Tracker': 'Issue Tracker',
  },
  'kn': {
    'profile': 'ಪ್ರೊಫೈಲ್',
    'notificationSettings': 'ಅಧಿಸೂಚನೆ ಸೆಟ್ಟಿಂಗ್‌ಗಳು',
    'faqs': 'ಪ್ರಶ್ನೋತ್ತರ',
    'support': 'ಸಹಾಯ',
    'aboutApp': 'ಆಪ್ ಬಗ್ಗೆ',
    'localStorage': 'ಸ್ಥಳೀಯ ಸಂಗ್ರಹಣೆ',
    'language': 'ಭಾಷೆ',
    'chooseLanguage': 'ಭಾಷೆ ಆಯ್ಕೆಮಾಡಿ',
    'cancel': 'ರದ್ದು',
    'personalInformation': 'ವೈಯಕ್ತಿಕ ಮಾಹಿತಿ',
    'phone': 'ಫೋನ್',
    'location': 'ಸ್ಥಳ',
    'email': 'ಇಮೇಲ್',
    'managerCode': 'ಮ್ಯಾನೇಜರ್ ಕೋಡ್',
    'farmManager': 'ಫಾರ್ಮ್ ಮ್ಯಾನೇಜರ್',
    'notLinked': 'ಲಿಂಕ್ ಆಗಿಲ್ಲ',
    'farmDetails': 'ಫಾರ್ಮ್ ವಿವರಗಳು',
    'landSize': 'ಭೂಮಿ ಗಾತ್ರ',
    'totalTrees': 'ಒಟ್ಟು ಮರಗಳು',
    'mainCrops': 'ಮುಖ್ಯ ಬೆಳೆಗಳು',
    'irrigation': 'ನೀರಾವರಿ',
    'editProfile': 'ಪ್ರೊಫೈಲ್ ಸಂಪಾದಿಸಿ',
    'resetPassword': 'ಪಾಸ್‌ವರ್ಡ್ ಮರುಹೊಂದಿಸಿ',
    'logout': 'ಲಾಗ್ ಔಟ್',
    'home': 'ಮುಖಪುಟ',
    'myTrees': 'ನನ್ನ ಮರಗಳು',
    'report': 'ವರದಿ',
    'namaste': 'ನಮಸ್ತೆ',
    'activityLog': 'ಚಟುವಟಿಕೆ ದಾಖಲೆ',
    'notifications': 'ಅಧಿಸೂಚನೆಗಳು',
    'syncStatusPanel': 'ಸಿಂಕ್ ಸ್ಥಿತಿ ಪ್ಯಾನಲ್',
    'online': 'ಆನ್‌ಲೈನ್',
    'offline': 'ಆಫ್‌ಲೈನ್',
    'healthy': 'ಆರೋಗ್ಯಕರ',
    'needAttention': 'ಗಮನ ಬೇಕು',
    'humidity': 'ಆರ್ದ್ರತೆ',
    'wind': 'ಗಾಳಿ',
    'rain': 'ಮಳೆ',
    'clouds': 'ಮೋಡಗಳು',
    'currentLocation': 'ಪ್ರಸ್ತುತ ಸ್ಥಳ',
    'gettingWeather': 'ಸ್ಥಳ ಮತ್ತು ಹವಾಮಾನ ಪಡೆಯಲಾಗುತ್ತಿದೆ...',
    'weatherAfterAccess': 'ಸ್ಥಳ ಅನುಮತಿಯ ನಂತರ ಹವಾಮಾನ ಕಾಣಿಸುತ್ತದೆ.',
    'refreshWeather': 'ಹವಾಮಾನ ರಿಫ್ರೆಶ್ ಮಾಡಿ',
    'Welcome Back': 'ಮತ್ತೆ ಸ್ವಾಗತ',
    'Sign in with your registered email address.':
        'ನಿಮ್ಮ ನೋಂದಾಯಿತ ಇಮೇಲ್ ವಿಳಾಸದಿಂದ ಸೈನ್ ಇನ್ ಮಾಡಿ.',
    'Email Address': 'ಇಮೇಲ್ ವಿಳಾಸ',
    'Password': 'ಪಾಸ್‌ವರ್ಡ್',
    'Forget password?': 'ಪಾಸ್‌ವರ್ಡ್ ಮರೆತಿರಾ?',
    'LOG IN': 'ಲಾಗ್ ಇನ್',
    'OR': 'ಅಥವಾ',
    "Don't have an account? ": 'ಖಾತೆ ಇಲ್ಲವೇ? ',
    'SIGN UP': 'ಸೈನ್ ಅಪ್',
    'Create Account': 'ಖಾತೆ ರಚಿಸಿ',
    'Create an account with email and password.':
        'ಇಮೇಲ್ ಮತ್ತು ಪಾಸ್‌ವರ್ಡ್ ಬಳಸಿ ಖಾತೆ ರಚಿಸಿ.',
    'Full Name': 'ಪೂರ್ಣ ಹೆಸರು',
    'Phone Number': 'ಫೋನ್ ಸಂಖ್ಯೆ',
    'Farm Manager Code (Optional)': 'ಫಾರ್ಮ್ ಮ್ಯಾನೇಜರ್ ಕೋಡ್ (ಐಚ್ಛಿಕ)',
    'Add a farm manager code only if you want to work under that manager.':
        'ಆ ಮ್ಯಾನೇಜರ್ ಅಡಿಯಲ್ಲಿ ಕೆಲಸ ಮಾಡಲು ಬಯಸಿದರೆ ಮಾತ್ರ ಕೋಡ್ ಸೇರಿಸಿ.',
    'Confirm Password': 'ಪಾಸ್‌ವರ್ಡ್ ದೃಢೀಕರಿಸಿ',
    'Farmer': 'ರೈತ',
    'Farm Manager': 'ಫಾರ್ಮ್ ಮ್ಯಾನೇಜರ್',
    'Your farm manager code will be generated automatically after registration.':
        'ನೋಂದಣಿಯ ನಂತರ ನಿಮ್ಮ ಫಾರ್ಮ್ ಮ್ಯಾನೇಜರ್ ಕೋಡ್ ಸ್ವಯಂಚಾಲಿತವಾಗಿ ರಚನೆಯಾಗುತ್ತದೆ.',
    'Already have an account? ': 'ಈಗಾಗಲೇ ಖಾತೆ ಇದೆಯೇ? ',
    'LOGIN': 'ಲಾಗಿನ್',
    'Forget Password': 'ಪಾಸ್‌ವರ್ಡ್ ಮರೆತಿದೆ',
    'Enter your Email to receive a password reset link':
        'ಪಾಸ್‌ವರ್ಡ್ ಮರುಹೊಂದಿಸುವ ಲಿಂಕ್ ಪಡೆಯಲು ಇಮೇಲ್ ನಮೂದಿಸಿ',
    'SEND RESET LINK': 'ಮರುಹೊಂದಿಸುವ ಲಿಂಕ್ ಕಳುಹಿಸಿ',
    'Back to Login': 'ಲಾಗಿನ್‌ಗೆ ಹಿಂತಿರುಗಿ',
    'Please enter email': 'ದಯವಿಟ್ಟು ಇಮೇಲ್ ನಮೂದಿಸಿ',
    'Enter valid email': 'ಸರಿಯಾದ ಇಮೇಲ್ ನಮೂದಿಸಿ',
    'Reset link sent to your email':
        'ಮರುಹೊಂದಿಸುವ ಲಿಂಕ್ ನಿಮ್ಮ ಇಮೇಲ್‌ಗೆ ಕಳುಹಿಸಲಾಗಿದೆ',
    'Something went wrong': 'ಏನೋ ತಪ್ಪಾಗಿದೆ',
    'Error occurred': 'ದೋಷ ಸಂಭವಿಸಿದೆ',
    'All': 'ಎಲ್ಲ',
    'At Risk': 'ಅಪಾಯದಲ್ಲಿದೆ',
    'Search by Tree ID, Location...': 'ಮರ ID, ಸ್ಥಳದಿಂದ ಹುಡುಕಿ...',
    'Scan History': 'ಸ್ಕ್ಯಾನ್ ಇತಿಹಾಸ',
    'Farmer Issues': 'ರೈತರ ಸಮಸ್ಯೆಗಳು',
    'Issues': 'ಸಮಸ್ಯೆಗಳು',
    'No scan history available yet.': 'ಇನ್ನೂ ಸ್ಕ್ಯಾನ್ ಇತಿಹಾಸ ಇಲ್ಲ.',
    'No issue reports available yet.': 'ಇನ್ನೂ ಸಮಸ್ಯೆ ವರದಿಗಳು ಇಲ್ಲ.',
    'Need Help? Contact Us': 'ಸಹಾಯ ಬೇಕೇ? ನಮ್ಮನ್ನು ಸಂಪರ್ಕಿಸಿ',
    'Describe your issue': 'ನಿಮ್ಮ ಸಮಸ್ಯೆಯನ್ನು ವಿವರಿಸಿ',
    'Describe your issue...': 'ನಿಮ್ಮ ಸಮಸ್ಯೆಯನ್ನು ವಿವರಿಸಿ...',
    'Please describe your issue': 'ದಯವಿಟ್ಟು ನಿಮ್ಮ ಸಮಸ್ಯೆಯನ್ನು ವಿವರಿಸಿ',
    'Submitted successfully': 'ಯಶಸ್ವಿಯಾಗಿ ಸಲ್ಲಿಸಲಾಗಿದೆ',
    'Submit': 'ಸಲ್ಲಿಸಿ',
    'My Farm': 'ನನ್ನ ಫಾರ್ಮ್',
    'Analytics': 'ವಿಶ್ಲೇಷಣೆ',
    'User Management': 'ಬಳಕೆದಾರ ನಿರ್ವಹಣೆ',
    'Activity Overview': 'ಚಟುವಟಿಕೆ ಅವಲೋಕನ',
    'Admin Alerts': 'ನಿರ್ವಾಹಕ ಎಚ್ಚರಿಕೆಗಳು',
    'Open Issues': 'ಸಮಸ್ಯೆಗಳನ್ನು ತೆರೆಯಿರಿ',
    'Total Managed Farms': 'ಒಟ್ಟು ನಿರ್ವಹಿತ ಫಾರ್ಮ್‌ಗಳು',
    'Total Issues': 'ಒಟ್ಟು ಸಮಸ್ಯೆಗಳು',
    'Critical': 'ಗಂಭೀರ',
    'Farm Directory': 'ಫಾರ್ಮ್ ಡೈರೆಕ್ಟರಿ',
    'Issue Tracker': 'ಸಮಸ್ಯೆ ಟ್ರ್ಯಾಕರ್',
  },
  'hi': {
    'profile': 'प्रोफ़ाइल',
    'notificationSettings': 'सूचना सेटिंग्स',
    'faqs': 'सामान्य प्रश्न',
    'support': 'सहायता',
    'aboutApp': 'ऐप के बारे में',
    'localStorage': 'स्थानीय संग्रहण',
    'language': 'भाषा',
    'chooseLanguage': 'भाषा चुनें',
    'cancel': 'रद्द करें',
    'personalInformation': 'व्यक्तिगत जानकारी',
    'phone': 'फ़ोन',
    'location': 'स्थान',
    'email': 'ईमेल',
    'managerCode': 'मैनेजर कोड',
    'farmManager': 'फार्म मैनेजर',
    'notLinked': 'लिंक नहीं है',
    'farmDetails': 'फार्म विवरण',
    'landSize': 'भूमि का आकार',
    'totalTrees': 'कुल पेड़',
    'mainCrops': 'मुख्य फसलें',
    'irrigation': 'सिंचाई',
    'editProfile': 'प्रोफ़ाइल संपादित करें',
    'resetPassword': 'पासवर्ड रीसेट करें',
    'logout': 'लॉग आउट',
    'home': 'होम',
    'myTrees': 'मेरे पेड़',
    'report': 'रिपोर्ट',
    'namaste': 'नमस्ते',
    'activityLog': 'गतिविधि लॉग',
    'notifications': 'सूचनाएं',
    'syncStatusPanel': 'सिंक स्थिति पैनल',
    'online': 'ऑनलाइन',
    'offline': 'ऑफ़लाइन',
    'healthy': 'स्वस्थ',
    'needAttention': 'ध्यान चाहिए',
    'humidity': 'नमी',
    'wind': 'हवा',
    'rain': 'बारिश',
    'clouds': 'बादल',
    'currentLocation': 'वर्तमान स्थान',
    'gettingWeather': 'स्थान और मौसम लिया जा रहा है...',
    'weatherAfterAccess': 'स्थान अनुमति के बाद मौसम दिखेगा.',
    'refreshWeather': 'मौसम रीफ्रेश करें',
    'Welcome Back': 'वापस स्वागत है',
    'Sign in with your registered email address.':
        'अपने पंजीकृत ईमेल पते से साइन इन करें.',
    'Email Address': 'ईमेल पता',
    'Password': 'पासवर्ड',
    'Forget password?': 'पासवर्ड भूल गए?',
    'LOG IN': 'लॉग इन',
    'OR': 'या',
    "Don't have an account? ": 'खाता नहीं है? ',
    'SIGN UP': 'साइन अप',
    'Create Account': 'खाता बनाएं',
    'Create an account with email and password.':
        'ईमेल और पासवर्ड से खाता बनाएं.',
    'Full Name': 'पूरा नाम',
    'Phone Number': 'फ़ोन नंबर',
    'Farm Manager Code (Optional)': 'फार्म मैनेजर कोड (वैकल्पिक)',
    'Add a farm manager code only if you want to work under that manager.':
        'यदि आप उस मैनेजर के अंतर्गत काम करना चाहते हैं तभी कोड जोड़ें.',
    'Confirm Password': 'पासवर्ड पुष्टि करें',
    'Farmer': 'किसान',
    'Farm Manager': 'फार्म मैनेजर',
    'Your farm manager code will be generated automatically after registration.':
        'पंजीकरण के बाद आपका फार्म मैनेजर कोड अपने आप बनेगा.',
    'Already have an account? ': 'पहले से खाता है? ',
    'LOGIN': 'लॉगिन',
    'Forget Password': 'पासवर्ड भूल गए',
    'Enter your Email to receive a password reset link':
        'पासवर्ड रीसेट लिंक पाने के लिए अपना ईमेल दर्ज करें',
    'SEND RESET LINK': 'रीसेट लिंक भेजें',
    'Back to Login': 'लॉगिन पर वापस जाएं',
    'Please enter email': 'कृपया ईमेल दर्ज करें',
    'Enter valid email': 'मान्य ईमेल दर्ज करें',
    'Reset link sent to your email': 'रीसेट लिंक आपके ईमेल पर भेजा गया',
    'Something went wrong': 'कुछ गलत हुआ',
    'Error occurred': 'त्रुटि हुई',
    'All': 'सभी',
    'At Risk': 'जोखिम में',
    'Search by Tree ID, Location...': 'पेड़ ID, स्थान से खोजें...',
    'Scan History': 'स्कैन इतिहास',
    'Farmer Issues': 'किसान समस्याएं',
    'Issues': 'समस्याएं',
    'No scan history available yet.': 'अभी कोई स्कैन इतिहास उपलब्ध नहीं है.',
    'No issue reports available yet.': 'अभी कोई समस्या रिपोर्ट उपलब्ध नहीं है.',
    'How to scan a tree?': 'पेड़ को कैसे स्कैन करें?',
    "Go to the dashboard and tap on 'Scan Now'. Use the camera to scan the RFID tag attached to the tree.":
        "डैशबोर्ड पर जाएं और 'Scan Now' दबाएं. पेड़ से जुड़े RFID टैग को स्कैन करें.",
    'How to view reports?': 'रिपोर्ट कैसे देखें?',
    'Navigate to the Reports tab from the bottom menu to see all your tree reports and analytics.':
        'नीचे मेनू से Reports टैब में जाकर सभी पेड़ रिपोर्ट और विश्लेषण देखें.',
    'How to update profile?': 'प्रोफ़ाइल कैसे अपडेट करें?',
    "Go to Profile screen and click on 'Edit Profile' to update your details.":
        "Profile स्क्रीन पर जाएं और 'Edit Profile' दबाकर विवरण अपडेट करें.",
    'Need Help? Contact Us': 'मदद चाहिए? संपर्क करें',
    'Describe your issue': 'अपनी समस्या लिखें',
    'Describe your issue...': 'अपनी समस्या लिखें...',
    'Please describe your issue': 'कृपया अपनी समस्या लिखें',
    'Submitted successfully': 'सफलतापूर्वक जमा हुआ',
    'Submit': 'जमा करें',
    'My Farm': 'मेरा फार्म',
    'Analytics': 'विश्लेषण',
    'User Management': 'उपयोगकर्ता प्रबंधन',
    'Add, edit, and remove users': 'उपयोगकर्ता जोड़ें, संपादित करें और हटाएं',
    'Activity Overview': 'गतिविधि अवलोकन',
    'Open the admin activity overview': 'व्यवस्थापक गतिविधि अवलोकन खोलें',
    'Open your profile settings': 'अपनी प्रोफ़ाइल सेटिंग खोलें',
    'Sign out from admin dashboard': 'व्यवस्थापक डैशबोर्ड से साइन आउट करें',
    'Admin Alerts': 'व्यवस्थापक अलर्ट',
    'No active alerts right now.': 'अभी कोई सक्रिय अलर्ट नहीं है.',
    'Open Issues': 'समस्याएं खोलें',
    'Do you want to sign out from the admin dashboard?':
        'क्या आप व्यवस्थापक डैशबोर्ड से साइन आउट करना चाहते हैं?',
    'Total Managed Farms': 'कुल प्रबंधित फार्म',
    'Total Issues': 'कुल समस्याएं',
    'Critical': 'गंभीर',
    'Farm Directory': 'फार्म डायरेक्टरी',
    'Issue Tracker': 'समस्या ट्रैकर',
  },
  'ta': {
    'profile': 'சுயவிவரம்',
    'notificationSettings': 'Notification Settings',
    'faqs': 'FAQs',
    'support': 'Support',
    'aboutApp': 'About App',
    'localStorage': 'Local Storage',
    'language': 'மொழி',
    'chooseLanguage': 'மொழியைத் தேர்ந்தெடுக்கவும்',
    'cancel': 'ரத்து',
    'personalInformation': 'தனிப்பட்ட தகவல்',
    'phone': 'தொலைபேசி',
    'location': 'இடம்',
    'email': 'மின்னஞ்சல்',
    'managerCode': 'Manager Code',
    'farmManager': 'Farm Manager',
    'notLinked': 'இணைக்கப்படவில்லை',
    'farmDetails': 'பண்ணை விவரங்கள்',
    'landSize': 'நில அளவு',
    'totalTrees': 'மொத்த மரங்கள்',
    'mainCrops': 'முக்கிய பயிர்கள்',
    'irrigation': 'பாசனம்',
    'editProfile': 'சுயவிவரம் திருத்து',
    'resetPassword': 'கடவுச்சொல் மீட்டமை',
    'logout': 'வெளியேறு',
    'home': 'முகப்பு',
    'myTrees': 'என் மரங்கள்',
    'report': 'அறிக்கை',
    'namaste': 'வணக்கம்',
    'activityLog': 'Activity Log',
    'notifications': 'Notifications',
    'syncStatusPanel': 'SYNC STATUS PANEL',
    'online': 'ஆன்லைன்',
    'offline': 'ஆஃப்லைன்',
    'healthy': 'ஆரோக்கியம்',
    'needAttention': 'கவனம் தேவை',
    'humidity': 'ஈரப்பதம்',
    'wind': 'காற்று',
    'rain': 'மழை',
    'clouds': 'மேகங்கள்',
    'currentLocation': 'தற்போதைய இடம்',
    'gettingWeather': 'இடம் மற்றும் வானிலை பெறப்படுகிறது...',
    'weatherAfterAccess': 'இட அனுமதிக்குப் பிறகு வானிலை தெரியும்.',
    'refreshWeather': 'வானிலை புதுப்பி',
  },
  'te': {
    'profile': 'ప్రొఫైల్',
    'notificationSettings': 'Notification Settings',
    'faqs': 'FAQs',
    'support': 'Support',
    'aboutApp': 'About App',
    'localStorage': 'Local Storage',
    'language': 'భాష',
    'chooseLanguage': 'భాషను ఎంచుకోండి',
    'cancel': 'రద్దు',
    'personalInformation': 'వ్యక్తిగత సమాచారం',
    'phone': 'ఫోన్',
    'location': 'స్థానం',
    'email': 'ఇమెయిల్',
    'managerCode': 'Manager Code',
    'farmManager': 'Farm Manager',
    'notLinked': 'లింక్ కాలేదు',
    'farmDetails': 'ఫార్మ్ వివరాలు',
    'landSize': 'భూమి పరిమాణం',
    'totalTrees': 'మొత్తం చెట్లు',
    'mainCrops': 'ప్రధాన పంటలు',
    'irrigation': 'పారుదల',
    'editProfile': 'ప్రొఫైల్ సవరించు',
    'resetPassword': 'పాస్‌వర్డ్ రీసెట్',
    'logout': 'లాగ్ అవుట్',
    'home': 'హోమ్',
    'myTrees': 'నా చెట్లు',
    'report': 'రిపోర్ట్',
    'namaste': 'నమస్తే',
    'activityLog': 'Activity Log',
    'notifications': 'Notifications',
    'syncStatusPanel': 'SYNC STATUS PANEL',
    'online': 'ఆన్‌లైన్',
    'offline': 'ఆఫ్‌లైన్',
    'healthy': 'ఆరోగ్యంగా',
    'needAttention': 'శ్రద్ధ అవసరం',
    'humidity': 'తేమ',
    'wind': 'గాలి',
    'rain': 'వర్షం',
    'clouds': 'మేఘాలు',
    'currentLocation': 'ప్రస్తుత స్థానం',
    'gettingWeather': 'స్థానం మరియు వాతావరణం పొందుతోంది...',
    'weatherAfterAccess': 'స్థాన అనుమతి తర్వాత వాతావరణం కనిపిస్తుంది.',
    'refreshWeather': 'వాతావరణం రిఫ్రెష్ చేయండి',
  },
};
