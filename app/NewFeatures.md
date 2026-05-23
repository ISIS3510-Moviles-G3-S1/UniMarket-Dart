# Sprint 4 — New Features Spec (Donation + Bartering)

This document is the joint implementation contract for two new features added in Sprint 4 of UniMarket: a **Donation flow** and a **Bartering / Trade Proposals** flow. It is consumed by two coding agents working on two parallel codebases:

- **Claude Code** → SwiftUI + Firebase iOS app in this repo (`UniMarket-Swift/`).
- **Codex** → Flutter + Firebase Android app in the companion repo.

The two implementations must be **behaviourally identical** (same screens, same names, same Firestore documents, same analytics event names) so the joint Firebase Analytics dashboard works for both teams. The two implementations may differ in their *technical* tooling (SwiftData vs. sqflite, NSCache vs. LinkedHashMap LRU, etc.) — each platform should pick the tooling that maximises rubric coverage on its side.

Each defendant is graded against a **per-person** Sprint 4 rubric. The rubric pillars are the same on both platforms; only the wording of the strategies differs. Every section below names the exact data structure, exact concurrency primitive, exact view, and exact event so the agents do not have to invent.

---

## 0. Rubric reminder (what graders check, per person)

| Pillar | Pts | What the grader will probe in the viva |
|---|---|---|
| Multithreading | 20 | "Show the code. Explain the scope. Explain the dispatcher/Isolate decision." Aim for **two cooperating concurrency primitives** + **at least one CPU-bound task moved off main**. |
| Local Storage | 20 | Stack 3 mechanisms: relational (10) + key-value or file (5) + UserDefaults/SharedPreferences (5). Don't lean on only one. |
| Eventual Connectivity | 20 | **5 pts per protected view, max 20.** Each view must have a *per-feature* offline affordance — pending pill, queued-action label, draft persistence, last-known-snapshot — never a generic "you're offline" banner. |
| Caching | 20 | Image cache (Kingfisher / cached_network_image — 5) **+** NSCache or LRU/LinkedHashMap (10) **+** a second cache structure (5). Explain countLimit, costLimit, eviction policy, and TTL. |
| Business Questions | 10 | Real-time pipeline → one shared Firebase dashboard → one chart you can point at. No CSV exports. |
| General Knowledge | 20 | Be able to explain the *other* features your teammates built on the same platform. Read the wiki. |

**Each new feature below is engineered so a single owner clears all 5 technical pillars from that feature alone.** Donation = one person's full rubric. Barter = the other person's full rubric. Reviews/Watchlist/Notifications from the existing Sprint 4 wiki are owned by other teammates and are out of scope for this document.

---

## 1. Shared product spec

### 1.1 New listing kind

`Product` (Swift: `Models/Product.swift`; Flutter: `lib/models/product.dart`) gains one new field:

```text
kind: ListingKind   // "sale" (default) | "donation" | "barter"
```

Firestore field: `kind` (string, default `"sale"`). Legacy docs without this field decode as `.sale`. Price is forced to `0` when `kind == .donation`; price is treated as a "reference value" (used for trade fairness scoring) when `kind == .barter`.

The Upload flow gets a 3-way segmented control: **Sell · Donate · Trade**. Selecting Donate hides the price field; selecting Trade keeps the price field (it acts as a reference for the fairness score) and adds a "Open to barter" badge on cards.

### 1.2 Two new Firestore collections

```text
/donationRequests/{requestID}
  donationListingID: string
  sellerID:          string
  requesterID:       string
  requesterMessage:  string?
  status:            "pending" | "approved" | "declined" | "withdrawn"
  createdAt:         timestamp
  resolvedAt:        timestamp?

/tradeProposals/{proposalID}
  fromUserID:        string   // proposer (also buyer-equivalent)
  toUserID:          string   // recipient (current owner of desired item)
  desiredListingID:  string
  offeredListingID:  string
  message:           string?
  status:            "pending" | "accepted" | "declined" | "withdrawn"
  priceDelta:        number   // signed; (offered.price - desired.price)
  createdAt:         timestamp
  resolvedAt:        timestamp?
```

Both collections allow read-by-participants and write-by-participants (Firestore rules are out of scope here — assume existing rule patterns for `chats` / `conversations` apply).

### 1.3 Shared analytics events

Both platforms emit the **same event names with the same parameter names**. Mismatch = broken dashboard.

```text
# Donation
donation_listing_created   { listing_id, category }
donation_browsed           { count_shown }
donation_claimed           { listing_id, seller_id, time_since_listing_seconds }
donation_approved          { listing_id, requester_id, wait_time_seconds }
donation_declined          { listing_id, requester_id }
donation_picked_up         { listing_id }                # fired from QR confirm when kind=donation

# Barter
trade_proposed             { desired_listing_id, offered_listing_id, price_delta }
trade_accepted             { proposal_id, wait_time_seconds }
trade_declined             { proposal_id, wait_time_seconds }
trade_completed            { proposal_id }               # fired from QR confirm when kind=barter
trade_match_score_viewed   { score_bucket }              # "0-25" | "25-50" | "50-75" | "75-100"
```

All events go through the existing `AnalyticsService` abstraction (Swift: `Services/AnalyticsService.swift`; Flutter: corresponding analytics helper). Add cases to the existing `AnalyticsEvent` enum on Swift; add named methods on the Flutter analytics helper.

---

# Feature 1 — Donation Flow

## 2. Donation: scope & screens

A seller can mark a listing as `kind = .donation` at upload time, or convert an existing sale listing into a donation (existing edit flow). Donation listings appear in a new dedicated browse view with a "Donations" filter chip on the main `BrowseSearchView`. Buyers tap **Claim** on a donation listing → a sheet collects an optional message → a `DonationRequest` is created. The seller sees received requests in an inbox under the Activity tab, picks one to approve, and the existing QR meetup flow finalises pickup.

### 2.1 Four screens (= EvC view budget)

| # | Screen | Path | Purpose |
|---|---|---|---|
| 1 | `DonationsBrowseView` | `Views/DonationsBrowseView.swift` / `lib/views/donations_browse_screen.dart` | Filtered grid of `kind == .donation` listings + filter chip on existing Browse. |
| 2 | `DonationRequestSheet` | `Views/DonationRequestSheet.swift` / `lib/views/donation_request_sheet.dart` | Sheet from `ProductDetailView` when `kind == .donation`. Optional message + Claim CTA. |
| 3 | `IncomingDonationRequestsView` | `Views/IncomingDonationRequestsView.swift` / `lib/views/incoming_donation_requests_screen.dart` | Seller inbox of requests grouped by listing. Approve/Decline per row. |
| 4 | `MyDonationsView` | `Views/MyDonationsView.swift` / `lib/views/my_donations_screen.dart` | Two tabs — *Given* (listings I donated) and *Claimed* (donations I requested), with status pills. |

Entry points: Donations chip on `BrowseSearchView`, new "Donation Requests" row on `ActivityView`, new "Mark as donation" toggle on the existing `UploadProductView` / `EditListingView`.

---

## 3. Donation — Swift implementation (Claude Code)

### 3.1 Files to add

```text
UniMarket-Swift/UniMarket-Swift/
├── Models/
│   ├── DonationRequest.swift              # struct + status enum, Firestore codec
│   └── ListingKind.swift                  # enum sale | donation | barter
├── Persistence/
│   ├── DonationRequestRecord.swift        # SwiftData @Model
│   └── DonationOfflineSnapshotStore.swift # JSON file snapshot for offline browse
├── Services/
│   ├── DonationService.swift              # Firestore CRUD (mirror ProductServices)
│   ├── PendingDonationsSyncer.swift       # @MainActor, binds to NetworkMonitor
│   ├── DonationRequesterProfileCache.swift # NSCache
│   └── DonationListingsLRU.swift          # custom LRU (capacity 16)
├── ViewModels/
│   ├── DonationsBrowseViewModel.swift
│   ├── DonationRequestViewModel.swift
│   ├── IncomingDonationRequestsViewModel.swift
│   └── MyDonationsViewModel.swift
└── Views/
    ├── DonationsBrowseView.swift
    ├── DonationRequestSheet.swift
    ├── IncomingDonationRequestsView.swift
    └── MyDonationsView.swift
```

Wire `PendingDonationsSyncer.shared.bind(to: NetworkMonitor.shared)` into `UniMarket_SwiftApp.body.task` next to the existing `bind(to:)` calls. Register the SwiftData `ModelContainer` for `DonationRequestRecord` in the same scene modifier the team uses for `ReviewRecord` (or create one if Reviews has not yet been merged).

### 3.2 SwiftData model — the relational pillar (10 pts)

```swift
@Model final class DonationRequestRecord {
    @Attribute(.unique) var id: String          // also the Firestore docID
    var donationListingID: String
    var sellerID: String
    var requesterID: String
    var requesterMessage: String
    var statusRaw: String                       // "pending" | "approved" | "declined" | "withdrawn"
    var createdAt: Date
    var resolvedAt: Date?
    var isSyncedClaim: Bool                     // requester wrote to Firestore
    var isSyncedDecision: Bool                  // seller decision wrote to Firestore
    var lastSyncAttemptAt: Date?
    var retryCount: Int

    var status: DonationRequestStatus {
        get { .init(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}
```

Use `@Query` with a `#Predicate` filter in every view so SwiftData pushes the seller/requester filter into SQLite (this is the same micro-optimisation the wiki praises for `SellerReviewsView` — explicitly call it out in the viva).

```swift
@Query(
    filter: #Predicate<DonationRequestRecord> { req in req.sellerID == currentUserID },
    sort: \DonationRequestRecord.createdAt, order: .reverse
) private var incoming: [DonationRequestRecord]
```

### 3.3 Eventual connectivity — 4 protected views (20 pts)

Mirror the existing `PendingListingMutationsSyncer` pattern exactly (`Services/PendingListingMutationsSyncer.swift`):

```swift
@MainActor
final class PendingDonationsSyncer: ObservableObject {
    static let shared = PendingDonationsSyncer()

    @Published private(set) var pendingClaimIDs:    Set<String> = []   // O(1) lookup from cards
    @Published private(set) var pendingDecisionIDs: Set<String> = []
    @Published private(set) var isDraining: Bool = false

    func bind(to monitor: NetworkMonitor) { /* same shape as PendingListingMutationsSyncer */ }
    func resumeIfNeeded() async              { /* drain on cold start */ }
    private func drain() async               { /* fetch unsynced, push to Firestore, mark synced */ }
}
```

**Per-view offline affordances (graders count these):**

| View | Offline affordance |
|---|---|
| `DonationsBrowseView` | Reads from `DonationOfflineSnapshotStore` (last successful Firestore fetch, JSON on disk) so the grid still renders. Shows a yellow "Last refreshed \<relative\>" caption. |
| `DonationRequestSheet` | Claim button stays enabled; label switches to **"Queue Claim"**. SwiftData write succeeds locally with `isSyncedClaim = false`; an inline banner says "We'll send this when you're back online." |
| `IncomingDonationRequestsView` | Approve/Decline buttons stay enabled; rows with `isSyncedDecision == false` show a small clock badge over the avatar (mirror the chat outbox affordance). |
| `MyDonationsView` | `@Query` snapshot always available; rows with `isSyncedClaim == false` show "Sending…" pill. Footer: "*N* claims syncing". |

The drain order matters: claims first (seller can't decide on a request that doesn't exist in Firestore yet), then decisions. Code this explicitly in `drain()`.

### 3.4 Multithreading — two cooperating primitives (20 pts)

| Task | Where | Primitive | Why |
|---|---|---|---|
| Parallel pre-flight on browse open | `DonationsBrowseViewModel.refresh()` | `async let listings = …; async let counts = …; let (l, c) = await (listings, counts)` | Two independent reads → `async let` is the right primitive (compile-time-known child count). |
| Inbox refresh + requester profile hydration | `IncomingDonationRequestsViewModel.refresh()` | `withTaskGroup(of: …)` with **`ConcurrencyLimiter(max: 8)`** actor | Variable child count = TaskGroup; concurrency cap protects URLSession pool on campus Wi-Fi (justify with the same reasoning the wiki uses for the Watchlist limiter). |
| Browse snapshot write to disk | `DonationOfflineSnapshotStore.persist(_:)` | Dedicated serial `DispatchQueue(label: "com.unimarket.donations.snapshot")` | Matches the `OrderSQLiteStore` style; cite that pattern in the viva. |
| SwiftData write-back after Firestore push | `PendingDonationsSyncer.drain()` | Background `ModelContext` (not the view's environment context) | Avoids contention with `@Query`; same trick the Reviews wiki uses. |
| Donation request counter aggregation | `actor DonationStatsAggregator` | `actor` | Several call sites mutate the per-listing pending-request count; the actor serialises updates. **Task Results worth 5–10 pts on the iOS rubric — make sure to demo `await aggregator.count(for: listingID)` in the viva.** |

Every `Task` opened inside a ViewModel is stored in a typed `Task<Void, Never>?` property and cancelled at the top of the next refresh and in `onDisappear`. Demo this cancellation explicitly.

### 3.5 Caching — three structures (20 pts)

| Cache | Backing | Parameters | Rationale |
|---|---|---|---|
| `DonationRequesterProfileCache` | `NSCache<NSString, CachedDonationRequester>` | `countLimit = 100`, `totalCostLimit = 128 * 1024`, per-entry `cost = displayName.utf8.count + (profilePic?.utf8.count ?? 0) + 32`, **TTL = 600s** soft (checked at lookup) | Inbox rows show requester avatars; without this cache, every snapshot tick re-reads `users/{uid}`. Mirrors `UserProfileCache`. **Invalidate on sign-out** via `Notification.userDidSignOut`. |
| `DonationListingsLRU` | Custom array-LRU, capacity **16** | Keyed by category string ("tops", "bottoms", …); value = `[Product]` last fetched | Donations are filtered by category from `DonationsBrowseView`; user revisits categories often. Mirrors `ProfileInsightsLRU`. **This is the 10-pt LRU structure — explain the eviction policy (remove-on-store + insert-at-MRU).** |
| Image cache | Kingfisher (already wired via `CachedRemoteImageView`) | Default config | 5 pts for the image-caching library bullet. |

### 3.6 Local storage stack — three mechanisms (20 pts)

| Mechanism | What it stores | Pts |
|---|---|---|
| SwiftData (`DonationRequestRecord`) | All donation requests, sync flags, retry metadata | **10** |
| File (`DonationOfflineSnapshotStore` → `applicationSupportDirectory/Donations/donations_browse_snapshot.json`) | Last successful browse fetch for offline render | 5 |
| `UserDefaults` key `unimarket.donations.unseenIncomingCount.<userID>` (Int) | Inbox badge counter | 5 |

### 3.7 Business Question (10 pts)

**Type 3 BQ:** *"Do users who claim a donation return to the marketplace to upload a paid listing within 30 days at a higher rate than users who only view paid listings?"*

- Events emitted: `donation_claimed`, `donation_approved`, `donation_picked_up`, plus the already-tracked `listing_submit_succeeded`.
- Pipeline: Firebase Analytics → existing team dashboard → **one Funnel Exploration** comparing the two cohorts. Reuse the dashboard from BQ#1 (chat-to-transaction) so graders see it lives in the same board.
- Demoable chart: a single bar chart `30-day return rate, claimed-donation cohort vs control`.

### 3.8 Donation Swift — rubric coverage checklist

- [ ] **Multithreading (20):** `async let` pre-flight, `withTaskGroup` + `ConcurrencyLimiter` actor, background `ModelContext`, `actor DonationStatsAggregator`, serial `DispatchQueue` for snapshot writes.
- [ ] **Local Storage (20):** SwiftData (10) + JSON snapshot file (5) + UserDefaults badge (5).
- [ ] **EvC (20):** 4 views, each with a per-feature affordance (last-known snapshot / queued claim / clock badge / sending pill).
- [ ] **Caching (20):** NSCache requester cache (parameters above) + custom LRU (capacity 16) + Kingfisher.
- [ ] **BQ (10):** Type 3 donation→relisting funnel on the existing Firebase dashboard.

---

## 4. Donation — Flutter implementation (Codex)

### 4.1 Files to add

```text
lib/
├── models/
│   ├── donation_request.dart              # value class + status enum + JSON codec
│   └── listing_kind.dart                  # enum sale | donation | barter
├── data/
│   ├── donation_requests_dao.dart         # sqflite table accessor
│   ├── donation_offline_snapshot.dart     # JSON file in app docs dir
│   ├── donation_drafts_box.dart           # Hive box for in-progress claim messages
│   └── donation_sync_queue.dart           # connectivity_plus listener + drain
├── services/
│   ├── donation_service.dart              # Firestore CRUD
│   ├── donation_requester_profile_cache.dart  # LinkedHashMap LRU (cap 100)
│   └── donation_listings_lru.dart         # LinkedHashMap LRU (cap 16) by category
├── view_models/
│   ├── donations_browse_view_model.dart   # ChangeNotifier
│   ├── donation_request_view_model.dart
│   ├── incoming_donation_requests_view_model.dart
│   └── my_donations_view_model.dart
└── views/
    ├── donations_browse_screen.dart
    ├── donation_request_sheet.dart
    ├── incoming_donation_requests_screen.dart
    └── my_donations_screen.dart
```

### 4.2 sqflite schema — the relational pillar (10 pts)

```sql
CREATE TABLE donation_requests (
  id                   TEXT PRIMARY KEY,
  donation_listing_id  TEXT NOT NULL,
  seller_id            TEXT NOT NULL,
  requester_id         TEXT NOT NULL,
  requester_message    TEXT,
  status               TEXT NOT NULL,
  created_at           INTEGER NOT NULL,
  resolved_at          INTEGER,
  is_synced_claim      INTEGER NOT NULL DEFAULT 0,
  is_synced_decision   INTEGER NOT NULL DEFAULT 0,
  last_sync_attempt_at INTEGER,
  retry_count          INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_dreq_seller    ON donation_requests(seller_id);
CREATE INDEX idx_dreq_requester ON donation_requests(requester_id);
CREATE INDEX idx_dreq_listing   ON donation_requests(donation_listing_id);
```

Push the seller/requester filter into the `WHERE` clause of every read — never `getAll().where(...)` in Dart. Mirror the Swift `#Predicate` argument in the viva ("we pushed the predicate into SQLite").

### 4.3 Eventual connectivity — 4 protected views (20 pts)

```dart
class DonationSyncQueue {
  DonationSyncQueue(this._dao, this._service);
  // Subscribes to Connectivity().onConnectivityChanged.
  // On offline → online transition, drain claims first, then decisions.
  // Each row update is mark-synced after a successful Firestore write.
}
```

Per-view affordances mirror Swift exactly:

| View | Affordance |
|---|---|
| `donations_browse_screen.dart` | Reads from `DonationOfflineSnapshot` JSON file when `connectivity == none`; renders the grid + "Last refreshed *<ago>*" caption. |
| `donation_request_sheet.dart` | CTA label switches to "Queue Claim" offline; row written to sqflite with `is_synced_claim=0` + Hive draft saved. Inline banner. |
| `incoming_donation_requests_screen.dart` | Approve/Decline stay enabled offline; rows with `is_synced_decision=0` show a clock badge. |
| `my_donations_screen.dart` | `StreamBuilder` over the sqflite query stays valid; "Sending…" pill rendered for unsynced rows. Footer counts unsynced. |

### 4.4 Multithreading (20 pts)

| Task | Where | Primitive | Why |
|---|---|---|---|
| Parallel pre-flight on browse | `DonationsBrowseViewModel.refresh()` | `Future.wait([fetchDonations(), fetchCategoryCounts()])` | Two independent network reads, fixed count. |
| Inbox refresh + requester profile hydration | `IncomingDonationRequestsViewModel.refresh()` | `Future.wait` over a *bounded* slice + handler in `.then((value) { … }).catchError(…)` for one of the calls (this is the "Future with handler" rubric line) | The rubric awards 5 pts for `Future`, 5 for `Future` *with handler*, 10 for `Future + handler + async/await` — wire all three idioms in one method to score the full 10. |
| Browse snapshot JSON write | `DonationOfflineSnapshot.persist(json)` | `compute(_serializeAndWrite, payload)` isolate | Moves JSON encoding off the UI thread. **Counts toward the 10-pt Isolate line.** |
| Live inbox updates | `DonationsService.watchInbox(sellerID)` | `Stream<List<DonationRequest>>` from Firestore | 5 pts for the Stream rubric line. |
| Donation stats aggregation | `compute(_aggregateDonationStats, payload)` | Second isolate | Confirms isolate use isn't a one-off (graders often probe). |

Net rubric coverage in this feature alone: Future (5) + Future-with-handler (5) + async/await + Future.wait (10 combined) + Stream (5) + Isolate (10) = stacks past 20, capped.

### 4.5 Caching (20 pts)

| Cache | Backing | Parameters |
|---|---|---|
| `DonationRequesterProfileCache` | `LinkedHashMap<String, _Entry>` LRU | `capacity = 100`, TTL = 600s, eviction = `removeFirst()` when `length > capacity`; insertion moves key to end via `remove` + `[]=`. Invalidated on sign-out. **This is the LRU pillar (10 pts).** |
| `DonationListingsLRU` | `LinkedHashMap<String, List<Product>>` | `capacity = 16`, keyed by category. Same LRU mechanics. |
| `cached_network_image` | Default config | Image cache (5 pts). |

Cache the Hive boxes themselves on first open (`Box? _box; if (_box != null) return _box!;`) — this is the **4.1.2 / 4.1.6 Hive Box Caching** micro-optimisation already credited in the wiki; reuse it for donation drafts and call it out.

### 4.6 Local storage stack (20 pts)

| Mechanism | What it stores | Pts |
|---|---|---|
| sqflite (`donation_requests` table) | All donation requests, sync flags | **10** |
| Hive box `donation_drafts_box` | In-progress claim messages (typed `DonationDraft` with typeId=21) | 5 |
| Local file `donations_browse_snapshot.json` in app docs | Offline browse render | 5 |
| `SharedPreferences` key `unimarket.donations.unseenIncomingCount.<uid>` | Inbox badge | 5 (caps stack at 20) |

### 4.7 Business Question (10 pts)

Identical to Swift — same events, same dashboard, same funnel chart.

### 4.8 Donation Flutter — rubric coverage checklist

- [ ] **Multithreading (20):** Future + handler + async/await + Future.wait + Stream + two `compute()` isolates.
- [ ] **Local Storage (20):** sqflite (10) + Hive (5) + JSON file (5) + SharedPreferences (5).
- [ ] **EvC (20):** 4 screens with per-screen affordances.
- [ ] **Caching (20):** LRU profile cache (10) + category LRU (5) + cached_network_image (5) + Hive box caching micro-opt.
- [ ] **BQ (10):** Same Type 3 funnel.

---

# Feature 2 — Bartering / Trade Proposals

## 5. Barter: scope & screens

From any product detail screen where `kind == .barter` (or even `kind == .sale` if "Open to barter" is set), a viewer taps **Propose Trade** → picks one of their own active listings to offer → confirms → a `TradeProposal` is created. The owner of the desired item sees proposals in a trade inbox under the Activity tab and accepts or declines. On acceptance, both items flip to `tradeLocked` (a new `ProductStatus` case) and the existing QR meetup flow confirms the swap, after which both listings transition to `.sold` with a `tradedWith` reference.

### 5.1 Four screens (= EvC view budget)

| # | Screen | Path |
|---|---|---|
| 1 | `ProposeTradeSheet` | `Views/ProposeTradeSheet.swift` / `lib/views/propose_trade_sheet.dart` |
| 2 | `TradeProposalsInboxView` | `Views/TradeProposalsInboxView.swift` / `lib/views/trade_proposals_inbox_screen.dart` |
| 3 | `MyTradeProposalsView` | `Views/MyTradeProposalsView.swift` / `lib/views/my_trade_proposals_screen.dart` |
| 4 | `TradeProposalDetailView` | `Views/TradeProposalDetailView.swift` / `lib/views/trade_proposal_detail_screen.dart` |

Entry points: **Propose Trade** button injected into the existing `ProductDetailView` action section (next to Message / Add to Cart). New "Trade Proposals" row on `ActivityView` linking to `TradeProposalsInboxView` (received) and `MyTradeProposalsView` (sent). The inbox view has a two-segment toggle: Received | Sent.

---

## 6. Barter — Swift implementation (Claude Code)

### 6.1 Files to add

```text
UniMarket-Swift/UniMarket-Swift/
├── Models/
│   ├── TradeProposal.swift                   # Firestore codec + status enum
│   └── TradeMatchScore.swift                 # struct { priceFairness, tagOverlap, total }
├── Persistence/
│   ├── TradeProposalRecord.swift             # SwiftData @Model
│   ├── TradeItemSnapshot.swift               # SwiftData @Model (child of proposal)
│   └── TradeProposalDraftStore.swift         # file-based draft persistence (sibling of ListingDraftStore)
├── Services/
│   ├── TradeService.swift                    # Firestore CRUD
│   ├── PendingTradesSyncer.swift             # @MainActor, binds to NetworkMonitor
│   ├── TradeCounterpartyProfileCache.swift   # NSCache
│   └── TradeMatchScoreLRU.swift              # custom LRU, capacity 64
├── ViewModels/
│   ├── ProposeTradeViewModel.swift
│   ├── TradeProposalsInboxViewModel.swift
│   ├── MyTradeProposalsViewModel.swift
│   └── TradeProposalDetailViewModel.swift
└── Views/
    ├── ProposeTradeSheet.swift
    ├── TradeProposalsInboxView.swift
    ├── MyTradeProposalsView.swift
    └── TradeProposalDetailView.swift
```

Bind `PendingTradesSyncer.shared.bind(to: NetworkMonitor.shared)` in `UniMarket_SwiftApp.body.task`.

### 6.2 SwiftData models — the relational pillar with cascade (10 pts)

The cascade relationship is the headline argument for the Local Storage pillar — explicitly model the proposal → snapshot relation so even deleted listings preserve enough state to render the inbox.

```swift
@Model final class TradeProposalRecord {
    @Attribute(.unique) var id: String
    var fromUserID: String                      // proposer
    var toUserID: String                        // recipient
    var desiredListingID: String
    var offeredListingID: String
    var message: String
    var statusRaw: String                       // "pending" | "accepted" | "declined" | "withdrawn"
    var priceDelta: Double
    var createdAt: Date
    var resolvedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \TradeItemSnapshot.proposal)
    var snapshots: [TradeItemSnapshot] = []

    var isSyncedProposal: Bool
    var isSyncedDecision: Bool
    var retryCount: Int
}

@Model final class TradeItemSnapshot {
    @Attribute(.unique) var id: String
    var listingID: String
    var title: String
    var imageURL: String
    var price: Double
    var ownerID: String
    var roleRaw: String                          // "offered" | "desired"
    var proposal: TradeProposalRecord?
}
```

Use `@Query(filter: #Predicate<TradeProposalRecord> { $0.toUserID == uid })` for the inbox view and `#Predicate { $0.fromUserID == uid }` for the outgoing view.

### 6.3 Eventual connectivity — 4 protected views (20 pts)

```swift
@MainActor
final class PendingTradesSyncer: ObservableObject {
    static let shared = PendingTradesSyncer()
    @Published private(set) var pendingProposalIDs: Set<String> = []
    @Published private(set) var pendingDecisionIDs: Set<String> = []
    // bind / drain / resumeIfNeeded — same shape as PendingListingMutationsSyncer
}
```

| View | Offline affordance |
|---|---|
| `ProposeTradeSheet` | "Propose" → "Queue Proposal" label. Sheet still writes the `TradeProposalRecord` locally with `isSyncedProposal = false` and snapshots already populated from the local `Product` cache. Inline banner. |
| `TradeProposalsInboxView` | `@Query` snapshot stays valid; Accept/Decline buttons stay enabled offline; rows with `isSyncedDecision == false` show a clock chip. |
| `MyTradeProposalsView` | Same `@Query` story; outgoing pending proposals show a "Pending sync" pill on the card. |
| `TradeProposalDetailView` | The two `TradeItemSnapshot` rows render from local data even when the underlying listings are deleted upstream. **Show this explicitly in the demo — it's the cascade argument.** |

Drafts of un-submitted proposals go to `TradeProposalDraftStore` (sibling of `ListingDraftStore`), so even a half-typed message survives a kill-and-relaunch — call this out as the file-based slice of EvC.

### 6.4 Multithreading — the headline feature for the iOS rubric (20 pts)

This is the feature where you stack every iOS rubric line.

| Task | Where | Primitive |
|---|---|---|
| Parallel pre-flight on `ProposeTradeSheet.onAppear` | `ProposeTradeViewModel.load(desiredListingID:)` | `async let mine = …; async let counterparty = …` — fetch owner's active listings + recipient profile in parallel. |
| Bulk fairness score recompute when offered list changes | `Task.detached(priority: .userInitiated) { … }` returning a `[String: TradeMatchScore]`, then `MainActor.run` to publish | **This is the "Task results" rubric line (5–10 pts) — make the detached task return a value via `await task.value`.** |
| Inbox refresh w/ profile hydration | `TradeProposalsInboxViewModel.refresh()` | `withTaskGroup(of: …)` + `ConcurrencyLimiter(max: 10)` (reuse the actor from donations) |
| Trade-unread-badge counter | `actor TradeBadgeCounter` exposing `await counter.increment() / .reset()` | One actor, multiple call sites (incoming push, view-open, accept) — clean demo of actor isolation. |
| Background ModelContext writes | `PendingTradesSyncer.drain()` | Background context, then publish to `@MainActor`. |

Net coverage: dispatcher coroutine (5) + multiple nested coroutines using I/O (10) + I/O + main (10) + Task results (10) = far past 20, capped.

### 6.5 Caching — LRU as headline (20 pts)

| Cache | Backing | Parameters |
|---|---|---|
| `TradeMatchScoreLRU` | Custom array-LRU (mirror `ProfileInsightsLRU`), capacity **64** | Keyed by `"\(min(a, b))|\(max(a, b))"` (order-independent), value = `TradeMatchScore`. Insertion: remove existing → insert at index 0 → drop tail beyond capacity. **This is the 10-pt LRU line. Demo the eviction trace in the viva.** |
| `TradeCounterpartyProfileCache` | `NSCache<NSString, CachedTradeProfile>` | `countLimit = 150`, `totalCostLimit = 192 * 1024`, `cost = displayName.utf8.count + (profilePic?.utf8.count ?? 0) + 32`, TTL = 600s soft. Sign-out invalidation. **5 pts (NSCache line — already covered by donation NSCache, but adds redundancy if graders deep-probe.)** |
| Kingfisher | Default | 5 pts image-cache line. |

**Why an LRU for the fairness score?** The score is `O(tags.count)` to compute and is read on every cell layout in `ProposeTradeSheet` (where the user picks which of their own listings to offer — each candidate row needs a score against the desired listing). Without the cache, scrolling a 40-item picker recomputes 40 scores per layout pass. The LRU memoises them keyed by the unordered listing pair, and the cache survives across the picker scroll and the proposal-detail navigation.

### 6.6 Local storage stack (20 pts)

| Mechanism | What it stores | Pts |
|---|---|---|
| SwiftData (`TradeProposalRecord` + `TradeItemSnapshot` with cascade) | All proposals + frozen item snapshots | **10** |
| File (`TradeProposalDraftStore` → `applicationSupportDirectory/TradeDrafts/<uid>/<draftID>.json`) | In-progress drafts | 5 |
| `UserDefaults` key `unimarket.trades.unreadInboxCount.<userID>` (Int) | Inbox badge | 5 |

### 6.7 Business Question (10 pts)

**Type 3 BQ:** *"Do listings that receive at least one trade proposal convert to a completed transaction (mark-as-sold OR trade-completed) at a materially higher rate than listings that only receive cart adds or views?"*

- Events emitted: `trade_proposed`, `trade_accepted`, `trade_completed`, joined with the existing `product_detail_viewed`, `cart_item_added`, `listing_marked_sold`.
- Pipeline: **Firebase Analytics → Funnel Exploration** on the team dashboard, side-by-side with the chat-to-transaction funnel from Sprint 3 (BQ#1).
- Demoable chart: completion rate of `product_detail_viewed → trade_proposed → trade_completed` vs. `product_detail_viewed → cart_item_added → listing_marked_sold`.

### 6.8 Barter Swift — rubric coverage checklist

- [ ] **Multithreading (20):** `async let`, `Task.detached` with `await task.value` results, `withTaskGroup` + `ConcurrencyLimiter`, `actor TradeBadgeCounter`, background `ModelContext`.
- [ ] **Local Storage (20):** SwiftData with cascade (10) + draft file store (5) + UserDefaults badge (5).
- [ ] **EvC (20):** 4 views with per-feature affordances; cascade snapshots prove the offline-survives-upstream-delete argument.
- [ ] **Caching (20):** Custom LRU (10) + NSCache (5) + Kingfisher (5).
- [ ] **BQ (10):** Type 3 trade-funnel vs cart-funnel comparison.

---

## 7. Barter — Flutter implementation (Codex)

### 7.1 Files to add

```text
lib/
├── models/
│   ├── trade_proposal.dart                  # + status enum
│   ├── trade_item_snapshot.dart
│   └── trade_match_score.dart
├── data/
│   ├── trade_proposals_dao.dart             # sqflite + FK + cascade
│   ├── trade_drafts_box.dart                # Hive box
│   ├── trade_inbox_snapshot.dart            # JSON file for offline inbox
│   └── trade_sync_queue.dart                # connectivity_plus listener
├── services/
│   ├── trade_service.dart                   # Firestore CRUD
│   ├── trade_counterparty_profile_cache.dart # LinkedHashMap LRU
│   ├── trade_match_score_lru.dart           # LinkedHashMap LRU, cap 64
│   └── trade_match_score_isolate.dart       # `compute()` entry point
├── view_models/
│   ├── propose_trade_view_model.dart
│   ├── trade_proposals_inbox_view_model.dart
│   ├── my_trade_proposals_view_model.dart
│   └── trade_proposal_detail_view_model.dart
└── views/
    ├── propose_trade_sheet.dart
    ├── trade_proposals_inbox_screen.dart
    ├── my_trade_proposals_screen.dart
    └── trade_proposal_detail_screen.dart
```

### 7.2 sqflite schema with FK cascade — the relational pillar (10 pts)

```sql
CREATE TABLE trade_proposals (
  id                    TEXT PRIMARY KEY,
  from_user_id          TEXT NOT NULL,
  to_user_id            TEXT NOT NULL,
  desired_listing_id    TEXT NOT NULL,
  offered_listing_id    TEXT NOT NULL,
  message               TEXT,
  status                TEXT NOT NULL,
  price_delta           REAL NOT NULL,
  created_at            INTEGER NOT NULL,
  resolved_at           INTEGER,
  is_synced_proposal    INTEGER NOT NULL DEFAULT 0,
  is_synced_decision    INTEGER NOT NULL DEFAULT 0,
  retry_count           INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_tp_to    ON trade_proposals(to_user_id);
CREATE INDEX idx_tp_from  ON trade_proposals(from_user_id);

CREATE TABLE trade_item_snapshots (
  id            TEXT PRIMARY KEY,
  proposal_id   TEXT NOT NULL,
  listing_id    TEXT NOT NULL,
  title         TEXT NOT NULL,
  image_url     TEXT,
  price         REAL NOT NULL,
  owner_id      TEXT NOT NULL,
  role          TEXT NOT NULL,                  -- "offered" | "desired"
  FOREIGN KEY (proposal_id) REFERENCES trade_proposals(id) ON DELETE CASCADE
);
```

Open the database with `onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON')` — sqflite does **not** enable FKs by default. Without that line the cascade silently doesn't fire and the rubric defense falls apart.

### 7.3 Eventual connectivity — 4 protected screens (20 pts)

```dart
class TradeSyncQueue {
  // Subscribes to Connectivity().onConnectivityChanged.
  // On offline → online: drain proposals (is_synced_proposal=0) first,
  // then decisions (is_synced_decision=0). Mark synced after success.
}
```

Affordance mapping mirrors Swift exactly:

| Screen | Affordance |
|---|---|
| `propose_trade_sheet.dart` | "Queue Proposal" label offline. Row written to sqflite + snapshots populated from local cache. |
| `trade_proposals_inbox_screen.dart` | `StreamBuilder` over sqflite query; clock chip per unsynced decision. |
| `my_trade_proposals_screen.dart` | Outgoing proposals show "Pending sync" pill. |
| `trade_proposal_detail_screen.dart` | Two cards always render from `trade_item_snapshots` even when the listing docs no longer exist upstream. |

### 7.4 Multithreading (20 pts) — Isolate is the headline

| Task | Where | Primitive |
|---|---|---|
| Parallel pre-flight on Propose Trade open | `ProposeTradeViewModel.load` | `Future.wait([fetchMyListings(), fetchCounterpartyProfile(), fetchDesiredListing()])` (Future + async/await — 10 pts combined) |
| Bulk fairness score recompute when picker opens | `compute(_calculateFairnessScores, payload)` returning `Map<String, double>` | **This is the headline Isolate (10 pts).** Payload: list of `(offeredID, desiredID, priceA, priceB, tagsA, tagsB)`. Output written back to `TradeMatchScoreLRU`. |
| Live inbox updates | `Stream<List<TradeProposal>>` from sqflite via rxdart `BehaviorSubject` (or Firestore stream merged with sqflite) | Stream rubric line (5 pts). |
| Per-row score fetch with handler | `_lru.lookupOrCompute(key).then(_onScoreReady).catchError(_onScoreFail)` | Future-with-handler line (5 pts). |
| Trade-badge counter | Single-isolate `ChangeNotifier` shared via Provider | Demo of isolated mutable state on main isolate. |

### 7.5 Caching (20 pts) — LRU pair as headline

| Cache | Backing | Parameters |
|---|---|---|
| `TradeMatchScoreLruCache` | `LinkedHashMap<String, double>` | `capacity = 64`. Key = `"$min|$max"` of the two listing IDs (unordered). Eviction: `if (length > capacity) remove(keys.first)`. Insertion: `remove(key); this[key] = value` to bump MRU. **10 pts LRU line.** |
| `TradeCounterpartyProfileCache` | `LinkedHashMap<String, _Entry>` LRU + TTL 600s | `capacity = 150`. Same LRU mechanics. 5 pts. |
| `cached_network_image` | Default | 5 pts image cache. |

Cache the trade-drafts Hive box on first open (same `Box? _box; if (_box != null) return _box!` micro-opt from the wiki).

### 7.6 Local storage stack (20 pts)

| Mechanism | What it stores | Pts |
|---|---|---|
| sqflite (`trade_proposals` + `trade_item_snapshots` with FK cascade) | All proposals + snapshots | **10** |
| Hive box `trade_drafts_box` | In-progress drafts | 5 |
| Local file `trade_inbox_snapshot.json` | Offline render of inbox | 5 |
| `SharedPreferences` key `unimarket.trades.unreadInboxCount.<uid>` | Badge | 5 (caps at 20) |

### 7.7 Business Question (10 pts)

Same as Swift — same events, same funnel, same dashboard.

### 7.8 Barter Flutter — rubric coverage checklist

- [ ] **Multithreading (20):** Future + handler + async/await + Future.wait (10) + Stream (5) + Isolate via `compute()` (10).
- [ ] **Local Storage (20):** sqflite with FK cascade (10) + Hive drafts (5) + JSON inbox snapshot (5) + SharedPreferences badge (5).
- [ ] **EvC (20):** 4 screens with per-screen affordances; FK cascade proves the upstream-delete-safety argument.
- [ ] **Caching (20):** LRU match scores (10) + LRU profiles (5) + cached_network_image (5).
- [ ] **BQ (10):** Trade-funnel vs cart-funnel comparison.

---

## 8. Cross-cutting tasks

### 8.1 Wiring into the existing app shell

**Swift (`App/UniMarket_SwiftApp.swift`):**

```swift
.task {
    // existing bind() calls …
    PendingDonationsSyncer.shared.bind(to: NetworkMonitor.shared)
    PendingTradesSyncer.shared.bind(to: NetworkMonitor.shared)
    await PendingDonationsSyncer.shared.resumeIfNeeded()
    await PendingTradesSyncer.shared.resumeIfNeeded()
}
```

Register the new SwiftData models in the existing `ModelContainer` config (same scene that already registers `ReviewRecord` from the Reviews feature).

**Flutter (`main.dart`):**

```dart
await DonationSyncQueue.instance.bind();
await TradeSyncQueue.instance.bind();
```

Both queues subscribe to `Connectivity().onConnectivityChanged` in their `bind()` and call `drain()` on every transition to a connected state.

### 8.2 Existing-view edits

| File | Edit |
|---|---|
| `Views/UploadProductView.swift` / `lib/views/upload_product_screen.dart` | Add Sell · Donate · Trade segmented control, hide price for Donate. |
| `Views/EditListingView.swift` / equivalent | Same segmented control on edit. |
| `Views/ProductDetailView.swift` / equivalent | Inject `WatchlistAddButton`-style buttons: "Claim" (donation) and "Propose Trade" (barter / open-to-barter). |
| `Views/BrowseSearchView.swift` / equivalent | Add a "Donations" filter chip and a "Open to trade" filter chip. |
| `Views/ActivityView.swift` / equivalent | Add rows: "Donation Requests", "Trade Proposals". |
| `Views/ScanQRView.swift` / equivalent | On QR confirm, branch on `kind`: emit `donation_picked_up`, `trade_completed`, or existing `listing_marked_sold`. |

### 8.3 Joint BQ dashboard (graders inspect one board)

The team already has a Firebase Analytics dashboard housing chat-to-transaction (BQ#1) and other Sprint 3 funnels. Add **two more cards** to that dashboard, do not create a new dashboard:

1. **Donation conversion funnel** — `donation_claimed → donation_approved → donation_picked_up`, plus a comparison: 30-day return rate for claimed-donation vs. cart-only cohorts.
2. **Trade conversion funnel** — `trade_proposed → trade_accepted → trade_completed`, plus the cart-vs-trade conversion comparison.

Both cohorts are derived in Firebase Analytics' built-in audience builder. No external pipeline.

### 8.4 Viva script (each defendant — 1 min opening)

Each owner uses this skeleton for their 1-minute opening:

> *"My feature is X. The four protected views are A, B, C, D — each has its own offline affordance, no global banner. Local storage uses [relational mechanism] for the main entity, [file/box] for [drafts/snapshot], and [UserDefaults/SharedPreferences] for the badge — that's 10 + 5 + 5. Caching uses [LRU type] keyed by [key shape] with capacity [N] and eviction [policy], plus [NSCache / LinkedHashMap] for [profile cache] and [Kingfisher / cached_network_image] for images. Multithreading uses [async let / Future.wait] for the pre-flight, [TaskGroup + ConcurrencyLimiter / compute() isolate] for the [variable-size or CPU-bound] step, and [Task.detached returning a value / Stream] for [task results / live updates]. My BQ is a Type 3 funnel on the shared dashboard — [name the chart]."*

Rehearse this. Graders pattern-match on technical vocabulary.

---

## 9. Definition of done (per feature, per platform)

- All 4 screens render with mock data on a clean install.
- All 4 screens render correctly with airplane mode toggled mid-session.
- Pending records survive force-quit and drain when connectivity returns.
- Every analytics event listed in §1.3 fires in the Firebase DebugView on the corresponding user action.
- The joint dashboard has the two new cards from §8.3 visible.
- Each defendant can answer "show the code" for every pillar in §0 within 30 seconds.
