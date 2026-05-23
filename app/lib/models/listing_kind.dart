enum ListingKind {
  sale,
  donation,
  barter,
}

ListingKind listingKindFromString(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'donation':
      return ListingKind.donation;
    case 'barter':
      return ListingKind.barter;
    case 'sale':
    default:
      return ListingKind.sale;
  }
}

String listingKindToString(ListingKind kind) {
  switch (kind) {
    case ListingKind.donation:
      return 'donation';
    case ListingKind.barter:
      return 'barter';
    case ListingKind.sale:
      return 'sale';
  }
}
