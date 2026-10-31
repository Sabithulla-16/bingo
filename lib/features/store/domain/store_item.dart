import 'package:flutter/material.dart';

/// Supported customization categories in the Customization Vault.
enum StoreCategory {
  all('Featured', 'all'),
  board('Board Themes', 'board'),
  numbers('Number Styles', 'numbers'),
  avatar('Avatars', 'avatar'),
  victory('Victory Effects', 'victory'),
  frame('Profile Frames', 'frame'),
  sound('Sound Packs', 'sound');

  final String label;
  final String key;
  const StoreCategory(this.label, this.key);

  static StoreCategory fromKey(String key) {
    return StoreCategory.values.firstWhere(
      (c) => c.key == key,
      orElse: () => StoreCategory.all,
    );
  }
}

/// Status of an item for the current player.
enum StoreItemStatus {
  available,
  owned,
  equipped;

  bool get isEquipped => this == StoreItemStatus.equipped;
  bool get isOwned => this == StoreItemStatus.owned;
  bool get isAvailable => this == StoreItemStatus.available;
}

/// Immutable domain model for a cosmetic customization product in BINGO.
@immutable
class StoreItem {
  final int id;
  final StoreCategory category;
  final String title;
  final String typeName;
  final int price;
  final String description;
  final String themeKey;
  final String previewType;
  final StoreItemStatus status;

  const StoreItem({
    required this.id,
    required this.category,
    required this.title,
    required this.typeName,
    required this.price,
    required this.description,
    this.themeKey = '',
    this.previewType = '',
    this.status = StoreItemStatus.available,
  });

  bool get isFree => price == 0;

  StoreItem copyWith({
    int? id,
    StoreCategory? category,
    String? title,
    String? typeName,
    int? price,
    String? description,
    String? themeKey,
    String? previewType,
    StoreItemStatus? status,
  }) {
    return StoreItem(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      typeName: typeName ?? this.typeName,
      price: price ?? this.price,
      description: description ?? this.description,
      themeKey: themeKey ?? this.themeKey,
      previewType: previewType ?? this.previewType,
      status: status ?? this.status,
    );
  }

  /// The standard, approved catalog of 12 items from Google Stitch.
  static List<StoreItem> get catalog => const [
    // 1. Classic Cream
    StoreItem(
      id: 1,
      category: StoreCategory.board,
      title: 'Classic Cream',
      typeName: 'Board Theme',
      price: 0,
      description:
          'The iconic, gentle Scandinavian paper board look. Restful on the eyes during prolonged social matches.',
      themeKey: 'classic',
      status: StoreItemStatus.equipped,
    ),
    // 2. Lavender Dream
    StoreItem(
      id: 2,
      category: StoreCategory.board,
      title: 'Lavender Dream',
      typeName: 'Board Theme',
      price: 100,
      description:
          'Soft, soothing pastel tones designed to soften tension and bring an editorial, relaxed vibe to high-speed rounds.',
      themeKey: 'lavender',
      status: StoreItemStatus.owned,
    ),
    // 3. Midnight Blue
    StoreItem(
      id: 3,
      category: StoreCategory.board,
      title: 'Midnight Blue',
      typeName: 'Board Theme',
      price: 200,
      description:
          'Deep nocturnal navy canvas paired with vibrant coral punch markers for intense visual contrast.',
      themeKey: 'midnight',
      status: StoreItemStatus.available,
    ),
    // 4. Neon Party
    StoreItem(
      id: 4,
      category: StoreCategory.board,
      title: 'Neon Party',
      typeName: 'Board Theme',
      price: 300,
      description:
          'Dark charcoal arcade background with electric coral and neon yellow accents. Highly energetic daubs.',
      themeKey: 'neon',
      status: StoreItemStatus.available,
    ),
    // 5. Classic Numbers
    StoreItem(
      id: 5,
      category: StoreCategory.numbers,
      title: 'Classic Numbers',
      typeName: 'Number Style',
      price: 0,
      description:
          'Standard balanced Outfit sans-serif typeface, optimized for glanceable high-speed daubing across 75 balls.',
      previewType: 'font',
      status: StoreItemStatus.equipped,
    ),
    // 6. Bold Numbers
    StoreItem(
      id: 6,
      category: StoreCategory.numbers,
      title: 'Bold Numbers',
      typeName: 'Number Style',
      price: 150,
      description:
          'Ultra heavy headline geometric numbers for crisp visual punch across the entire board.',
      previewType: 'font-bold',
      status: StoreItemStatus.available,
    ),
    // 7. Fun Collection
    StoreItem(
      id: 7,
      category: StoreCategory.avatar,
      title: 'Fun Collection',
      typeName: 'Avatars',
      price: 200,
      description:
          'Playful geometric character set featuring lucky cats, vintage daubers, and smiling bingo balls.',
      previewType: 'avatar',
      status: StoreItemStatus.available,
    ),
    // 8. Golden Burst
    StoreItem(
      id: 8,
      category: StoreCategory.victory,
      title: 'Golden Burst',
      typeName: 'Victory Effect',
      price: 350,
      description:
          'An explosive golden radial starburst cascade celebrating your BINGO calls on all player screens.',
      previewType: 'victory',
      status: StoreItemStatus.available,
    ),
    // 9. Golden Frame
    StoreItem(
      id: 9,
      category: StoreCategory.frame,
      title: 'Golden Frame',
      typeName: 'Profile Frame',
      price: 250,
      description:
          'An elegant, hand-finished golden rim highlighting your profile badge across leaderboards and match rooms.',
      previewType: 'frame',
      status: StoreItemStatus.available,
    ),
    // 10. Classic Sounds
    StoreItem(
      id: 10,
      category: StoreCategory.sound,
      title: 'Classic Sounds',
      typeName: 'Sound Pack',
      price: 0,
      description:
          'Timeless wooden dauber thuds, gentle chime calls, and balanced acoustic bell acoustics.',
      previewType: 'sound-classic',
      status: StoreItemStatus.equipped,
    ),
    // 11. Arcade Sounds
    StoreItem(
      id: 11,
      category: StoreCategory.sound,
      title: 'Arcade Sounds',
      typeName: 'Sound Pack',
      price: 300,
      description:
          '8-bit retro arcade synthesized arpeggios, punchy coin taps, and high-energy 90s win fanfares.',
      previewType: 'sound-arcade',
      status: StoreItemStatus.available,
    ),
    // 12. Celebration Sounds
    StoreItem(
      id: 12,
      category: StoreCategory.sound,
      title: 'Celebration Sounds',
      typeName: 'Sound Pack',
      price: 400,
      description:
          'Triumphant brass fanfares, concert hall cheering, and festive confetti pop audio accents.',
      previewType: 'sound-celebration',
      status: StoreItemStatus.available,
    ),
  ];
}
