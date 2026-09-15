import 'package:flutter/widgets.dart';

/// Tiny hand-rolled localisation (en / hi / gu) - no codegen needed.
class SoluStrings {
  static String lang = 'hi';

  static const List<Map<String, String>> languages = [
    {'code': 'hi', 'label': 'Hindi', 'native': 'हिंदी'},
    {'code': 'gu', 'label': 'Gujarati', 'native': 'ગુજરાતી'},
    {'code': 'en', 'label': 'English', 'native': 'English'},
  ];

  static const Map<String, Map<String, String>> _v = {
    'en': {
      'choose_language': 'Choose your language',
      'continue': 'Continue',
      'get_started': 'Get started',
      'skip': 'Skip',
      'next': 'Next',
      'home': 'Home',
      'explore': 'Explore',
      'videos': 'My videos',
      'profile': 'Profile',
      'hero_title': 'Turn one photo into a film',
      'hero_sub': 'Heavenly tribute videos for the people you miss',
      'featured': 'Featured',
      'all_scenes': 'All scenes',
      'categories': 'Categories',
      'use_scene': 'Use this scene',
      'add_photo': 'Add photo',
      'change_photo': 'Change photo',
      'photo_tips': 'Photo tips',
      'tip_1': 'Clear front-facing face',
      'tip_2': 'Good light, no blur',
      'tip_3': 'One person only',
      'generate': 'Create video',
      'generating': 'Creating your video',
      'please_wait': 'This takes 2-5 minutes. Keep the app open.',
      'done': 'Your video is ready',
      'save': 'Save',
      'share': 'Share',
      'again': 'Create again',
      'no_videos': 'No videos yet',
      'no_videos_sub': 'Your creations will appear here',
      'gallery': 'Gallery',
      'camera': 'Camera',
      'error_generic': 'Something went wrong. Please try again.',
      'retry': 'Retry',
      'second_photo': 'Second photo',
      'needs_two': 'This scene needs 2 photos',
      'language': 'Language',
      'privacy': 'Privacy policy',
      'support': 'Contact support',
      'not_configured': 'App is not connected to the server yet.',
      'respect_note':
          'Please use tribute scenes only for people who have passed away, with family consent.',
      'i_agree': 'I understand',
    },
    'hi': {
      'choose_language': 'अपनी भाषा चुनें',
      'continue': 'आगे बढ़ें',
      'get_started': 'शुरू करें',
      'skip': 'छोड़ें',
      'next': 'आगे',
      'home': 'होम',
      'explore': 'एक्सप्लोर',
      'videos': 'मेरी वीडियो',
      'profile': 'प्रोफ़ाइल',
      'hero_title': 'एक फ़ोटो से बनाएँ पूरी फ़िल्म',
      'hero_sub': 'अपने प्रियजनों के लिए स्वर्ग वीडियो',
      'featured': 'ख़ास',
      'all_scenes': 'सभी सीन',
      'categories': 'श्रेणियाँ',
      'use_scene': 'यह सीन चुनें',
      'add_photo': 'फ़ोटो जोड़ें',
      'change_photo': 'फ़ोटो बदलें',
      'photo_tips': 'फ़ोटो के सुझाव',
      'tip_1': 'चेहरा साफ़ और सामने से',
      'tip_2': 'अच्छी रोशनी, धुंधला नहीं',
      'tip_3': 'केवल एक व्यक्ति',
      'generate': 'वीडियो बनाएँ',
      'generating': 'आपकी वीडियो बन रही है',
      'please_wait': '2-5 मिनट लगेंगे। ऐप खुला रखें।',
      'done': 'आपकी वीडियो तैयार है',
      'save': 'सेव',
      'share': 'शेयर',
      'again': 'फिर बनाएँ',
      'no_videos': 'अभी कोई वीडियो नहीं',
      'no_videos_sub': 'आपकी बनाई वीडियो यहाँ दिखेंगी',
      'gallery': 'गैलरी',
      'camera': 'कैमरा',
      'error_generic': 'कुछ गड़बड़ हो गई। दोबारा कोशिश करें।',
      'retry': 'दोबारा',
      'second_photo': 'दूसरी फ़ोटो',
      'needs_two': 'इस सीन के लिए 2 फ़ोटो चाहिए',
      'language': 'भाषा',
      'privacy': 'प्राइवेसी पॉलिसी',
      'support': 'सहायता',
      'not_configured': 'ऐप अभी सर्वर से नहीं जुड़ा है।',
      'respect_note':
          'श्रद्धांजलि सीन केवल दिवंगत प्रियजनों के लिए, परिवार की सहमति से बनाएँ।',
      'i_agree': 'समझ गया',
    },
    'gu': {
      'choose_language': 'તમારી ભાષા પસંદ કરો',
      'continue': 'આગળ વધો',
      'get_started': 'શરૂ કરો',
      'skip': 'છોડો',
      'next': 'આગળ',
      'home': 'હોમ',
      'explore': 'એક્સપ્લોર',
      'videos': 'મારા વિડિયો',
      'profile': 'પ્રોફાઇલ',
      'hero_title': 'એક ફોટોમાંથી બનાવો આખી ફિલ્મ',
      'hero_sub': 'સ્વર્ગસ્થ સ્વજનો માટે શ્રદ્ધાંજલિ વિડિયો',
      'featured': 'ખાસ',
      'all_scenes': 'બધા સીન',
      'categories': 'શ્રેણીઓ',
      'use_scene': 'આ સીન પસંદ કરો',
      'add_photo': 'ફોટો ઉમેરો',
      'change_photo': 'ફોટો બદલો',
      'photo_tips': 'ફોટો સૂચનો',
      'tip_1': 'ચહેરો સ્પષ્ટ અને સામેથી',
      'tip_2': 'સારો પ્રકાશ, ઝાંખું નહીં',
      'tip_3': 'ફક્ત એક વ્યક્તિ',
      'generate': 'વિડિયો બનાવો',
      'generating': 'તમારો વિડિયો બની રહ્યો છે',
      'please_wait': '2-5 મિનિટ લાગશે. એપ ખુલ્લી રાખો.',
      'done': 'તમારો વિડિયો તૈયાર છે',
      'save': 'સેવ',
      'share': 'શેર',
      'again': 'ફરી બનાવો',
      'no_videos': 'હજી કોઈ વિડિયો નથી',
      'no_videos_sub': 'તમારા બનાવેલા વિડિયો અહીં દેખાશે',
      'gallery': 'ગેલેરી',
      'camera': 'કેમેરા',
      'error_generic': 'કંઈક ખોટું થયું. ફરી પ્રયાસ કરો.',
      'retry': 'ફરી પ્રયાસ',
      'second_photo': 'બીજો ફોટો',
      'needs_two': 'આ સીન માટે 2 ફોટો જોઈએ',
      'language': 'ભાષા',
      'privacy': 'પ્રાઇવસી પોલિસી',
      'support': 'સહાય',
      'not_configured': 'એપ હજી સર્વર સાથે જોડાયેલી નથી.',
      'respect_note':
          'શ્રદ્ધાંજલિ સીન ફક્ત સ્વર્ગસ્થ સ્વજનો માટે, પરિવારની સંમતિથી બનાવો.',
      'i_agree': 'સમજ્યો',
    },
  };

  static String t(String key) =>
      _v[lang]?[key] ?? _v['en']?[key] ?? key;
}

/// Shorthand: `S.of(context)` not needed - strings are global.
String tr(String key) => SoluStrings.t(key);

/// Rebuilds the whole app when language changes.
class LanguageScope extends StatefulWidget {
  const LanguageScope({super.key, required this.child});
  final Widget child;

  static _LanguageScopeState? _state;

  static void setLanguage(String code) {
    SoluStrings.lang = code;
    _state?.refresh();
  }

  @override
  State<LanguageScope> createState() => _LanguageScopeState();
}

class _LanguageScopeState extends State<LanguageScope> {
  @override
  void initState() {
    super.initState();
    LanguageScope._state = this;
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: ValueKey(SoluStrings.lang), child: widget.child);
}
