/// A reference-to-video scene. Prompts live on the server only.
class Scene {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final int seconds;
  final int photos;
  final String poster;
  final bool featured;
  final bool sensitive;

  const Scene({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.seconds,
    required this.poster,
    this.photos = 1,
    this.featured = false,
    this.sensitive = false,
  });

  bool get needsTwoPhotos => photos == 2;
  String get durationLabel => '$seconds sec';

  factory Scene.fromJson(Map<String, dynamic> j) => Scene(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? '',
        subtitle: (j['subtitle'] as String?) ?? '',
        category: (j['category'] as String?) ?? 'Shraddhanjali',
        seconds: (j['seconds'] as num?)?.toInt() ?? 10,
        photos: (j['photos'] as num?)?.toInt() ?? 1,
        poster: (j['poster'] as String?) ?? 'assets/posters/swarg.jpg',
        featured: (j['featured'] as bool?) ?? false,
        sensitive: (j['sensitive'] as bool?) ?? false,
      );
}

/// Local catalogue - also the offline fallback when /v1/scenes is unreachable.
/// Keep ids in sync with worker/src/index.ts SCENES.
class SceneCatalog {
  static const List<Scene> all = [
    Scene(
      id: 'swarg_darwaza',
      title: 'Swarg Ka Darwaza',
      subtitle: 'Alvida kehkar sone ke darwaze se swarg mein',
      category: 'Shraddhanjali',
      seconds: 10,
      poster: 'assets/posters/swarg.jpg',
      featured: true,
      sensitive: true,
    ),
    Scene(
      id: 'swarg_pushpak',
      title: 'Pushpak Viman',
      subtitle: 'Divya viman mein baadalon ke paar',
      category: 'Shraddhanjali',
      seconds: 10,
      poster: 'assets/posters/krishna.jpg',
      featured: true,
      sensitive: true,
    ),
    Scene(
      id: 'swarg_seedhi',
      title: 'Prakash Ki Seedhi',
      subtitle: 'Roshni ki seedhiyon par shaanti se',
      category: 'Shraddhanjali',
      seconds: 10,
      poster: 'assets/posters/ganesha.jpg',
      sensitive: true,
    ),
    Scene(
      id: 'shraddhanjali_frame',
      title: 'Shraddhanjali',
      subtitle: 'Haar chadhi tasveer, diya aur shraddha',
      category: 'Shraddhanjali',
      seconds: 8,
      poster: 'assets/posters/diwali.jpg',
      sensitive: true,
    ),
    Scene(
      id: 'ashirwad_haath',
      title: 'Ashirwad',
      subtitle: 'Sar par pyaar bhara haath, ashirwad',
      category: 'Blessing',
      seconds: 8,
      poster: 'assets/posters/ganpati.jpg',
      featured: true,
      sensitive: true,
    ),
    Scene(
      id: 'heaven_hug',
      title: 'Aakhri Mulaqat',
      subtitle: 'Do apne swarg mein phir milte hain',
      category: 'Reunion',
      seconds: 10,
      photos: 2,
      poster: 'assets/posters/wedding.jpg',
      sensitive: true,
    ),
    Scene(
      id: 'yaad_pyari',
      title: 'Pyari Yaadein',
      subtitle: 'Purani tasveer mein jaan, halki muskaan',
      category: 'Memory',
      seconds: 8,
      poster: 'assets/posters/oldphoto.jpg',
      featured: true,
    ),
  ];

  static List<Scene> get featured =>
      all.where((s) => s.featured).toList(growable: false);

  static List<String> get categories {
    final seen = <String>[];
    for (final s in all) {
      if (!seen.contains(s.category)) seen.add(s.category);
    }
    return seen;
  }

  static List<Scene> byCategory(String c) =>
      all.where((s) => s.category == c).toList(growable: false);

  static Scene? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Posters are bundled, so merge server metadata with local artwork.
  static String posterFor(String id) =>
      byId(id)?.poster ?? 'assets/posters/swarg.jpg';
}
