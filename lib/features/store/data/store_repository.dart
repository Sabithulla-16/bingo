import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/error_logger.dart';
import '../../../data/supabase/supabase_provider.dart';
import '../../authentication/domain/auth_repository.dart';
import '../../profile/domain/player_customization.dart';
import '../../profile/domain/profile_repository.dart';
import '../domain/store_item.dart';

abstract class StoreRepository {
  Future<List<StoreItem>> getItems();
  Future<void> purchaseItem(int itemId);
  Future<void> equipItem(int itemId);
  Stream<List<StoreItem>> watchItems();
  StoreItem? getEquippedItem(StoreCategory category);
  PlayerCustomization get currentCustomization;
  Stream<PlayerCustomization> watchCustomization();
}

class StoreRepositoryImpl implements StoreRepository {
  final SupabaseClient? _supabase;
  final AuthRepository _authRepo;
  final ProfileRepository _profileRepo;

  static const String _prefOwnedKey = 'bingo_store_owned_items';
  static const String _prefEquippedKey = 'bingo_store_equipped_items';

  final _itemsController = StreamController<List<StoreItem>>.broadcast();
  final _customizationController =
      StreamController<PlayerCustomization>.broadcast();
  List<StoreItem> _cachedItems = StoreItem.catalog;
  PlayerCustomization _currentCustomization = const PlayerCustomization();

  StoreRepositoryImpl({
    SupabaseClient? supabase,
    required AuthRepository authRepo,
    required ProfileRepository profileRepo,
  }) : _supabase = supabase,
       _authRepo = authRepo,
       _profileRepo = profileRepo {
    _loadState();
  }

  String get _userId => _authRepo.currentUserId ?? 'guest';

  bool get _isOnline => _supabase != null && _supabase.auth.currentUser != null;

  @override
  PlayerCustomization get currentCustomization => _currentCustomization;

  @override
  Stream<PlayerCustomization> watchCustomization() =>
      _customizationController.stream;

  PlayerCustomization _customizationFromEquippedMap(Map<String, int> equipped) {
    return PlayerCustomization(
      boardThemeId: equipped['board'] ?? 1,
      numberStyleId: equipped['numbers'] ?? 5,
      avatarId: equipped['avatar'] ?? 7,
      victoryEffectId: equipped['victory'] ?? 0,
      profileFrameId: equipped['frame'] ?? 0,
      soundPackId: equipped['sound'] ?? 10,
    );
  }

  Future<void> _loadState() async {
    try {
      Set<int> owned = {1, 5, 10}; // Defaults are free/owned
      Map<String, int> equipped = {'board': 1, 'numbers': 5, 'sound': 10};

      if (_isOnline) {
        try {
          final res = await _supabase!
              .from('player_customizations')
              .select()
              .eq('user_id', _userId);

          for (final row in res as List) {
            final itemId = (row['item_id'] as num).toInt();
            final category = row['category'] as String;
            final isEquipped = row['is_equipped'] as bool? ?? false;
            owned.add(itemId);
            if (isEquipped) {
              equipped[category] = itemId;
            }
          }
        } catch (e, st) {
          ErrorLogger.logUnhandled(
            e,
            st,
            source: 'StoreRepositoryImpl._loadState',
          );
        }
      }

      // Check local cache
      final prefs = await SharedPreferences.getInstance();
      final localOwned = prefs.getStringList('${_prefOwnedKey}_$_userId');
      if (localOwned != null) {
        owned.addAll(localOwned.map(int.parse));
      }
      final localEquippedRaw = prefs.getString('${_prefEquippedKey}_$_userId');
      if (localEquippedRaw != null) {
        final decoded = Map<String, dynamic>.from(
          jsonDecode(localEquippedRaw) as Map,
        );
        decoded.forEach((cat, id) {
          equipped[cat] = (id as num).toInt();
        });
      }

      _currentCustomization = _customizationFromEquippedMap(equipped);
      _customizationController.add(_currentCustomization);

      _cachedItems = StoreItem.catalog.map((item) {
        final isEq = equipped[item.category.key] == item.id;
        final isOw = owned.contains(item.id) || item.isFree;

        if (isEq) {
          return item.copyWith(status: StoreItemStatus.equipped);
        } else if (isOw) {
          return item.copyWith(status: StoreItemStatus.owned);
        } else {
          return item.copyWith(status: StoreItemStatus.available);
        }
      }).toList();

      _itemsController.add(_cachedItems);
    } catch (_) {}
  }

  @override
  Future<List<StoreItem>> getItems() async {
    await _loadState();
    return _cachedItems;
  }

  @override
  Stream<List<StoreItem>> watchItems() {
    scheduleMicrotask(() {
      if (!_itemsController.isClosed) {
        _itemsController.add(List.unmodifiable(_cachedItems));
      }
    });
    return _itemsController.stream;
  }

  @override
  StoreItem? getEquippedItem(StoreCategory category) {
    try {
      return _cachedItems.firstWhere(
        (i) => i.category == category && i.status.isEquipped,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> purchaseItem(int itemId) async {
    final item = _cachedItems.firstWhere(
      (i) => i.id == itemId,
      orElse: () => throw StateError('Item $itemId not found in catalog'),
    );

    if (item.status.isOwned || item.status.isEquipped) {
      throw StateError('You already own this customization.');
    }

    final profile = await _profileRepo.getProfile(_userId);
    final currentChips = profile?.chips ?? 500;
    if (currentChips < item.price) {
      throw StateError(
        'Insufficient chips: you have $currentChips but need ${item.price}.',
      );
    }

    if (_isOnline) {
      try {
        final res = await _supabase!.rpc(
          'rpc_purchase_customization',
          params: {
            'p_item_id': itemId,
            'p_category': item.category.key,
            'p_price': item.price,
          },
        );
        if (res != null && res['new_balance'] != null) {
          final newBal = (res['new_balance'] as num).toInt();
          if (profile != null) {
            await _profileRepo.upsertProfile(profile.copyWith(chips: newBal));
          }
        }
      } catch (e, st) {
        ErrorLogger.logUnhandled(
          e,
          st,
          source: 'StoreRepositoryImpl.purchaseItem',
        );
        // If RPC failed due to missing migration, fallback to direct profile update
        final newBal = currentChips - item.price;
        if (profile != null) {
          await _profileRepo.upsertProfile(profile.copyWith(chips: newBal));
        }
      }
    } else {
      // Local / guest mode deduction
      final newBal = currentChips - item.price;
      if (profile != null) {
        await _profileRepo.upsertProfile(profile.copyWith(chips: newBal));
      }
    }

    // Save to local cache
    final prefs = await SharedPreferences.getInstance();
    final ownedList = prefs.getStringList('${_prefOwnedKey}_$_userId') ?? [];
    if (!ownedList.contains('$itemId')) {
      ownedList.add('$itemId');
      await prefs.setStringList('${_prefOwnedKey}_$_userId', ownedList);
    }

    // Update achievement progress for Collector (5 customizations)
    await _updateAchievementProgress('card-collector', ownedList.length);

    // Update memory items and notify
    _cachedItems = _cachedItems.map((it) {
      if (it.id == itemId) {
        return it.copyWith(status: StoreItemStatus.owned);
      }
      return it;
    }).toList();
    _itemsController.add(_cachedItems);
  }

  @override
  Future<void> equipItem(int itemId) async {
    final item = _cachedItems.firstWhere(
      (i) => i.id == itemId,
      orElse: () => throw StateError('Item $itemId not found in catalog'),
    );

    if (!item.status.isOwned && !item.isFree && !item.status.isEquipped) {
      throw StateError('You do not own this item yet.');
    }

    if (_isOnline) {
      try {
        await _supabase!.rpc(
          'rpc_equip_customization',
          params: {'p_item_id': itemId, 'p_category': item.category.key},
        );
      } catch (e, st) {
        ErrorLogger.logUnhandled(
          e,
          st,
          source: 'StoreRepositoryImpl.equipItem',
        );
      }
    }

    // Save locally
    final prefs = await SharedPreferences.getInstance();
    final localEquippedRaw = prefs.getString('${_prefEquippedKey}_$_userId');
    final Map<String, dynamic> equippedMap = localEquippedRaw != null
        ? Map<String, dynamic>.from(jsonDecode(localEquippedRaw) as Map)
        : {};
    equippedMap[item.category.key] = itemId;
    await prefs.setString(
      '${_prefEquippedKey}_$_userId',
      jsonEncode(equippedMap),
    );

    // Update memory items (one equipped per category)
    _cachedItems = _cachedItems.map((it) {
      if (it.category == item.category) {
        if (it.id == itemId) {
          return it.copyWith(status: StoreItemStatus.equipped);
        } else if (it.status.isEquipped) {
          return it.copyWith(status: StoreItemStatus.owned);
        }
      }
      return it;
    }).toList();
    _itemsController.add(_cachedItems);

    final Map<String, int> intEquippedMap = {};
    equippedMap.forEach((k, v) {
      intEquippedMap[k] = (v as num).toInt();
    });
    _currentCustomization = _customizationFromEquippedMap(intEquippedMap);
    _customizationController.add(_currentCustomization);

    // Update achievement progress for Style Explorer (equip first customization)
    await _updateAchievementProgress('card-style-explorer', 1);
  }

  Future<void> _updateAchievementProgress(String id, int progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const achKey = 'bingo_player_achievements';
      final localRaw = prefs.getString('${achKey}_$_userId');
      final Map<String, dynamic> stateMap = localRaw != null
          ? Map<String, dynamic>.from(jsonDecode(localRaw) as Map)
          : {};
      stateMap[id] = {
        'progress': progress,
        'is_unlocked': progress >= (id == 'card-style-explorer' ? 1 : 5),
        'is_claimed': false,
      };
      await prefs.setString('${achKey}_$_userId', jsonEncode(stateMap));
    } catch (_) {}
  }
}

class PlayerCustomizationNotifier extends StateNotifier<PlayerCustomization> {
  final StoreRepository _repo;
  StreamSubscription<PlayerCustomization>? _sub;

  PlayerCustomizationNotifier(this._repo) : super(_repo.currentCustomization) {
    _sub = _repo.watchCustomization().listen((updated) {
      state = updated;
    });
    // Trigger initial state load
    _repo.getItems().then((_) {
      state = _repo.currentCustomization;
    });
  }

  Future<void> equip(int itemId) async {
    await _repo.equipItem(itemId);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);

  return StoreRepositoryImpl(
    supabase: supabase,
    authRepo: authRepo,
    profileRepo: profileRepo,
  );
});

final storeItemsProvider = StreamProvider<List<StoreItem>>((ref) async* {
  final repo = ref.watch(storeRepositoryProvider);
  yield await repo.getItems();
  yield* repo.watchItems();
});

final playerCustomizationProvider =
    StateNotifierProvider<PlayerCustomizationNotifier, PlayerCustomization>((
      ref,
    ) {
      final repo = ref.watch(storeRepositoryProvider);
      return PlayerCustomizationNotifier(repo);
    });
