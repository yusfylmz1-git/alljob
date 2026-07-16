/// Türkçe arama için sadeleştirme (İ/I/ı, Ş/ş, …).
String foldTrSearch(String s) {
  return s
      .replaceAll('İ', 'i')
      .replaceAll('I', 'i')
      .replaceAll('ı', 'i')
      .replaceAll('Ş', 's')
      .replaceAll('ş', 's')
      .replaceAll('Ğ', 'g')
      .replaceAll('ğ', 'g')
      .replaceAll('Ü', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('Ö', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('Ç', 'c')
      .replaceAll('ç', 'c')
      .toLowerCase();
}

bool matchesTrSearch(String haystack, String query) {
  final q = foldTrSearch(query.trim());
  if (q.isEmpty) return true;
  return foldTrSearch(haystack).contains(q);
}
