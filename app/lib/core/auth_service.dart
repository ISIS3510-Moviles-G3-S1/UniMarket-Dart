import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_event.dart';
import 'analytics_service.dart';
import '../models/app_user.dart';
import 'auth_failure.dart';
import 'lru_cache.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // ── LRU profile cache ────────────────────────────────────────────────────
  // Capacity = 50: covers the logged-in user + seller profiles viewed in a
  // typical session without unbounded memory growth. Entries are promoted to
  // the MRU position on every read; the LRU entry is evicted on overflow.
  static final LruCache<String, AppUser> _profileCache =
      LruCache<String, AppUser>(capacity: 50);

  // ── SharedPreferences keys for session persistence ───────────────────────
  static const String _prefUid = 'auth_cached_uid';
  static const String _prefEmail = 'auth_cached_email';
  static const String _prefDisplayName = 'auth_cached_displayName';
  static const String _prefProfilePic = 'auth_cached_profilePic';
  static const String _prefXp = 'auth_cached_xpPoints';

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    debugPrint('[AuthService] signIn called with email: $email');

    // For testing: simulate auth failure
    if (email == "test@error.com") {
      debugPrint('[AuthService] Test error email detected, throwing AuthFailure');
      throw const AuthFailure('Invalid credentials', code: 'invalid-credential');
    }

    try {
      debugPrint('[AuthService] Calling Firebase signInWithEmailAndPassword');
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('[AuthService] Firebase signInWithEmailAndPassword succeeded');
      return await _hydrateUser(credential.user!);
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] FirebaseAuthException caught: ${e.code} - ${e.message}');
      throw AuthFailure.fromFirebaseException(e);
    } catch (e) {
      debugPrint('[AuthService] Unexpected error in signIn: $e');
      throw const AuthFailure('Unable to sign in. Please try again');
    }
  }

  Future<AppUser> signUp({
  required String email,
  required String password,
  String? displayName,
}) async {
  try {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user!;

    if (displayName != null && displayName.trim().isNotEmpty) {
      await user.updateDisplayName(displayName.trim());
    }

    final docRef = _firestore.collection('users').doc(user.uid);

    await docRef.set({
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': displayName ??
          user.displayName ??
          user.email?.split('@').first ??
          '',
      'profilePic': user.photoURL ?? '',
      'xpPoints': 0,
      'isVerified': false,
      'numTransactions': 0,
      'ratingStars': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    });
    
    final doc = await docRef.get();
    return AppUser.fromFirestore(doc);

  } on FirebaseAuthException catch (e) {
    throw AuthFailure.fromFirebaseException(e);
  } catch (e) {
    throw const AuthFailure('Unable to sign up. Please try again');
  }
}

  Future<void> signOut() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        _profileCache.invalidate(uid);
        debugPrint('[AuthService] LRU cache invalidated for uid=$uid');
      }
      await clearPersistedUser();
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromFirebaseException(e);
    } catch (_) {
      throw const AuthFailure('Unable to sign out. Please try again');
    }
  }

  /// Returns the last successfully hydrated [AppUser] persisted to
  /// SharedPreferences, or `null` if none is cached. Useful for populating
  /// the UI immediately on cold start before Firebase resolves.
  Future<AppUser?> getCachedSessionUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString(_prefUid);
      if (uid == null || uid.isEmpty) return null;
      final user = AppUser(
        uid: uid,
        email: prefs.getString(_prefEmail) ?? '',
        displayName: prefs.getString(_prefDisplayName) ?? '',
        profilePic: prefs.getString(_prefProfilePic) ?? '',
        xpPoints: prefs.getInt(_prefXp) ?? 0,
      );
      // Warm-up LRU so the first in-session hydrateUser() call is a cache hit.
      _profileCache.put(uid, user);
      debugPrint('[AuthService] getCachedSessionUser restored uid=$uid from prefs');
      return user;
    } catch (e) {
      debugPrint('[AuthService] getCachedSessionUser failed: $e');
      return null;
    }
  }

  /// Removes the persisted session from SharedPreferences.
  Future<void> clearPersistedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefUid);
      await prefs.remove(_prefEmail);
      await prefs.remove(_prefDisplayName);
      await prefs.remove(_prefProfilePic);
      await prefs.remove(_prefXp);
      debugPrint('[AuthService] clearPersistedUser done');
    } catch (e) {
      debugPrint('[AuthService] clearPersistedUser failed: $e');
    }
  }

  Future<AppUser> hydrateUser(User firebaseUser) {
    return _hydrateUser(firebaseUser);
  }

  Future<void> _persistUserToPrefs(AppUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefUid, user.uid);
      await prefs.setString(_prefEmail, user.email);
      await prefs.setString(_prefDisplayName, user.displayName);
      await prefs.setString(_prefProfilePic, user.profilePic);
      await prefs.setInt(_prefXp, user.xpPoints);
    } catch (e) {
      debugPrint('[AuthService] _persistUserToPrefs failed: $e');
    }
  }

  Future<AppUser> _hydrateUser(
    User firebaseUser, {
    String? overrideDisplayName,
  }) async {
    // ── LRU cache check ──────────────────────────────────────────────────────
    // A cache hit avoids a Firestore round-trip entirely. The entry is promoted
    // to the MRU position inside LruCache.get().
    final cached = _profileCache.get(firebaseUser.uid);
    if (cached != null) {
      debugPrint('[AuthService] _hydrateUser LRU HIT uid=${firebaseUser.uid}');
      return cached;
    }
    debugPrint('[AuthService] _hydrateUser LRU MISS uid=${firebaseUser.uid} — fetching Firestore');

    final docRef = _firestore.collection('users').doc(firebaseUser.uid);
    final doc = await docRef.get();

    if (doc.exists) {
      AppUser user = AppUser.fromFirestore(doc);
      if (user.profilePic.trim().isEmpty) {
        final authPhoto = firebaseUser.photoURL ?? '';
        if (authPhoto.trim().isNotEmpty) {
          user = user.copyWith(profilePic: authPhoto);
        }
      }
      _profileCache.put(user.uid, user);
      await _persistUserToPrefs(user);
      return user;
    }

    await docRef.set({
      'uid': firebaseUser.uid,
      'email': firebaseUser.email ?? '',
      'displayName': overrideDisplayName ??
          firebaseUser.displayName ??
          firebaseUser.email?.split('@').first ??
          '',
      'profilePic': firebaseUser.photoURL ?? '',
      'xpPoints': 0,
      'isVerified': false,
      'numTransactions': 0,
      'ratingStars': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    });

    final createdDoc = await docRef.get();
    if (createdDoc.exists) {
      return AppUser.fromFirestore(createdDoc);
    }

    return AppUser.fromFirebaseUser(firebaseUser);
  }

  /// Update lastLogin timestamp for user in Firestore and SharedPreferences
  Future<void> updateLastLogin(String uid) async {
    try {
      final now = DateTime.now();

      final docRef = _firestore.collection('users').doc(uid);
      final doc = await docRef.get();

      DateTime? existingLastLogin;
      if (doc.exists) {
        final data = doc.data() ?? <String, dynamic>{};
        final existingTimestamp = data['lastLogin'];
        if (existingTimestamp is Timestamp) {
          existingLastLogin = existingTimestamp.toDate();
        }
      }

      final updateData = <String, Object>{
        'lastLogin': FieldValue.serverTimestamp(),
      };
      if (existingLastLogin != null) {
        updateData['previousLogin'] = existingLastLogin;
      }

      await docRef.update(updateData);

      // Save to local SharedPreferences for quick access
      final prefs = await SharedPreferences.getInstance();
      if (existingLastLogin != null) {
        await prefs.setString('previousLogin_$uid', existingLastLogin.toIso8601String());
      }
      await prefs.setString('lastLogin_$uid', now.toIso8601String());

      debugPrint('[AuthService] Updated lastLogin for user $uid');
    } catch (e) {
      debugPrint('[AuthService] Error updating lastLogin: $e');
    }
  }

  /// Check if user is inactive for specified number of days
  /// Returns true if user hasn't logged in for >= days
  Future<bool> isInactiveForDays(String uid, {int days = 3}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final previousLoginStr = prefs.getString('previousLogin_$uid');
      final lastLoginStr = prefs.getString('lastLogin_$uid');

      DateTime? previousLogin;
      DateTime? lastLogin;

      if (previousLoginStr != null) {
        previousLogin = DateTime.tryParse(previousLoginStr);
      }

      if (lastLoginStr != null) {
        lastLogin = DateTime.tryParse(lastLoginStr);
      }

      if (previousLogin == null) {
        // Need a previous login to evaluate inactivity across sessions.
        // Try to load from Firestore.
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data() ?? <String, dynamic>{};
          final tsPrev = data['previousLogin'];
          final tsLast = data['lastLogin'];
          if (tsPrev is Timestamp) {
            previousLogin = tsPrev.toDate();
          }
          if (tsLast is Timestamp) {
            lastLogin ??= tsLast.toDate();
          }
        }
      }

      if (previousLogin == null) {
        debugPrint('[AuthService] No previousLogin found for user $uid');
        return false;
      }

      final now = DateTime.now();
      final daysSincePreviousLogin = now.difference(previousLogin).inDays;
      final isInactive = daysSincePreviousLogin >= days;

      debugPrint(
        '[AuthService] User $uid - Days since previous login: $daysSincePreviousLogin (Inactive: $isInactive)',
      );

      // --- Analytics: Type-2 Business Question (inactivity & re-engagement) ---
      AnalyticsService.instance.track(
        AnalyticsEvent.userInactivityChecked(
          userId: uid,
          daysSinceLastInteraction: daysSincePreviousLogin,
          isInactive: isInactive,
          thresholdDays: days,
        ),
      );

      if (isInactive) {
        AnalyticsService.instance.track(
          AnalyticsEvent.reengagementNotificationTriggered(
            userId: uid,
            daysInactive: daysSincePreviousLogin,
            thresholdDays: days,
          ),
        );
      } else {
        AnalyticsService.instance.track(
          AnalyticsEvent.userActiveNoNotification(
            userId: uid,
            daysSinceLastInteraction: daysSincePreviousLogin,
          ),
        );
      }
      // -----------------------------------------------------------------------

      return isInactive;
    } catch (e) {
      debugPrint('[AuthService] Error checking inactivity: $e');
      return false;
    }
  }
}

