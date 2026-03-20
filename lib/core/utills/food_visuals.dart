/// Resolves a relevant food emoji and background color for a given product name.
///
/// Used across inventory cards and forecast thumbnails so every product
/// shows a meaningful visual even before a real image URL is stored.
class FoodVisuals {
  FoodVisuals._();

  // ── keyword → emoji table ──────────────────────────────────────────────────
  // Ordered from most-specific to most-general so the first match wins.
  static const List<(List<String>, String)> _rules = [
    // ── Rice dishes ──
    (['jollof rice', 'jollof'], '🍛'),
    (['fried rice', 'coconut rice', 'ofada'], '🍚'),
    (['rice'], '🍚'),

    // ── Pasta / noodles ──
    (['spaghetti', 'pasta', 'macaroni', 'noodle'], '🍝'),

    // ── Bread / pastry ──
    (
      ['meat pie', 'meatpie', 'puff puff', 'puffpuff', 'chin chin', 'buns'],
      '🥧',
    ),
    (['bread', 'loaf', 'agege'], '🍞'),
    (['cake', 'cupcake', 'muffin'], '🎂'),
    (['biscuit', 'cookie', 'cracker'], '🍪'),
    (['doughnut', 'donut'], '🍩'),

    // ── Poultry ──
    (['chicken', 'turkey', 'suya', 'shawarma', 'grilled'], '🍗'),

    // ── Beef / meat ──
    (
      [
        'beef',
        'cow leg',
        'oxtail',
        'brisket',
        'steak',
        'burger',
        'hotdog',
        'sausage',
      ],
      '🥩',
    ),
    (['pork', 'bacon', 'ribs', 'ham'], '🥓'),
    (['meat', 'minced', 'kebab'], '🍖'),

    // ── Fish / seafood ──
    (
      [
        'fish',
        'catfish',
        'tilapia',
        'salmon',
        'tuna',
        'shrimp',
        'prawn',
        'crayfish',
      ],
      '🐟',
    ),
    (['crab', 'lobster', 'snail'], '🦞'),

    // ── Eggs ──
    (['egg', 'omelette', 'boiled egg'], '🥚'),

    // ── Soups / stews ──
    (['egusi', 'banga', 'ofe', 'okra soup', 'melon soup'], '🫕'),
    (['pepper soup', 'peppersoup', 'tomato stew', 'stew', 'sauce'], '🍲'),
    (['soup', 'porridge', 'pottage', 'asun'], '🍲'),

    // ── Swallows ──
    (['eba', 'garri'], '⬜'),
    (['fufu', 'amala', 'pounded yam', 'semovita', 'wheat', 'tuwo'], '🍡'),

    // ── Vegetables / salad ──
    (['salad', 'coleslaw', 'lettuce', 'cucumber'], '🥗'),
    (['yam', 'sweet potato', 'plantain', 'dodo', 'porridge yam'], '🍠'),
    (['potato', 'chips', 'crisps', 'fries', 'french fries'], '🍟'),
    (['beans', 'akara', 'moi moi', 'gbegiri'], '🫘'),
    (['corn', 'maize', 'popcorn'], '🌽'),
    (['vegetable', 'veggie', 'spinach', 'ugwu', 'waterleaf'], '🥬'),
    (['tomato'], '🍅'),
    (['pepper', 'chilli'], '🌶️'),
    (['onion'], '🧅'),
    (['carrot'], '🥕'),

    // ── Fruits / juice ──
    (['juice', 'smoothie', 'zobo', 'sobo', 'kunu', 'chapman'], '🧃'),
    (['banana', 'plantain chips'], '🍌'),
    (
      [
        'mango',
        'pawpaw',
        'papaya',
        'pineapple',
        'watermelon',
        'orange',
        'lemon',
        'lime',
        'apple',
      ],
      '🍉',
    ),
    (['fruit'], '🍑'),

    // ── Condiments / spices ──
    (['groundnut', 'peanut', 'nut'], '🥜'),
    (['butter', 'margarine', 'cream'], '🧈'),
    (['oil', 'palm oil', 'vegetable oil', 'olive oil'], '🫙'),
    (['salt', 'sugar', 'seasoning', 'maggi', 'knorr', 'spice', 'curry'], '🧂'),
    (['flour', 'semolina', 'cornstarch', 'baking'], '🌾'),

    // ── Dairy ──
    (['milk', 'cheese', 'yogurt', 'ice cream'], '🥛'),

    // ── Beverages ──
    (['tea', 'coffee', 'cocoa', 'milo', 'ovaltine', 'bournvita'], '☕'),
    (
      [
        'water',
        'mineral',
        'soft drink',
        'soda',
        'coke',
        'pepsi',
        'fanta',
        'sprite',
      ],
      '🥤',
    ),
    (['beer', 'wine', 'alcohol'], '🍺'),

    // ── Snacks (general) ──
    (['sandwich', 'wrap'], '🥪'),
    (['pizza'], '🍕'),
    (['snack'], '🍿'),
  ];

  /// Returns a single emoji character that best represents [name].
  /// Returns '🍽️' if no keyword matches.
  static String emojiFor(String name) {
    final lower = name.toLowerCase();
    for (final (keywords, emoji) in _rules) {
      for (final kw in keywords) {
        if (lower.contains(kw)) return emoji;
      }
    }
    return '🍽️';
  }

  /// Returns a soft background color that pairs well with the emoji.
  static ({int bg, int fg}) colorsFor(String name) {
    final emoji = emojiFor(name);
    return switch (emoji) {
      '🍛' || '🍚' => (bg: 0xFFFFF4D6, fg: 0xFF92400E),
      '🍝' => (bg: 0xFFFCEFDE, fg: 0xFF7B3E00),
      '🥧' || '🍞' || '🎂' || '🍪' || '🍩' => (bg: 0xFFFFF0E6, fg: 0xFF8B4513),
      '🍗' || '🍖' || '🥩' || '🥓' => (bg: 0xFFFFEEEE, fg: 0xFFC0392B),
      '🐟' || '🦞' => (bg: 0xFFE8F4FD, fg: 0xFF1565C0),
      '🥚' => (bg: 0xFFFFFDE7, fg: 0xFFF57F17),
      '🫕' || '🍲' => (bg: 0xFFFFECE6, fg: 0xFFBF360C),
      '🍠' || '🌽' => (bg: 0xFFFFF8E1, fg: 0xFFF57F17),
      '🥗' || '🥬' || '🍅' => (bg: 0xFFE8F5E9, fg: 0xFF1B5E20),
      '🧃' || '🥤' || '☕' || '🍺' => (bg: 0xFFE3F2FD, fg: 0xFF0D47A1),
      '🥛' => (bg: 0xFFF3E5F5, fg: 0xFF6A1B9A),
      '🫘' || '🥜' => (bg: 0xFFF1F8E9, fg: 0xFF33691E),
      _ => (bg: 0xFFF5F5F5, fg: 0xFF616161),
    };
  }
}
