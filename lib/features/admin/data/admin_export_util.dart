import '../../../data/models/app_user.dart';
import '../../../data/models/job.dart';
import '../../../data/models/artisan_profile.dart';

/// Client-side CSV helpers (MVP — yüklü sayfa; telefon yok).
String csvEscape(String? value) {
  final s = value ?? '';
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Kullanıcı meta CSV (PII minimize: phone yok).
String buildUsersCsv(List<AppUser> users) {
  final buf = StringBuffer(
      'uid,email,displayName,suspended,hasArtisanProfile,createdAt\n');
  for (final u in users) {
    buf.writeln([
      csvEscape(u.uid),
      csvEscape(u.email),
      csvEscape(u.displayName),
      u.suspended ? 'true' : 'false',
      u.hasArtisanProfile ? 'true' : 'false',
      csvEscape(u.createdAt.toUtc().toIso8601String()),
    ].join(','));
  }
  return buf.toString();
}

String buildJobsCsv(List<Job> jobs) {
  final buf = StringBuffer(
      'jobId,status,customerId,province,category,moderationHidden,createdAt\n');
  for (final j in jobs) {
    buf.writeln([
      csvEscape(j.jobId),
      csvEscape(j.status.name),
      csvEscape(j.customerId),
      csvEscape(j.province),
      csvEscape(j.category),
      j.moderationHidden ? 'true' : 'false',
      csvEscape(j.createdAt.toUtc().toIso8601String()),
    ].join(','));
  }
  return buf.toString();
}

String buildArtisansCsv(List<ArtisanProfile> profiles) {
  final buf = StringBuffer(
      'uid,profession,isVerified,adminVerified,featured,moderationHidden,averageRating,totalReviews,createdAt\n');
  for (final a in profiles) {
    buf.writeln([
      csvEscape(a.uid),
      csvEscape(a.profession),
      a.isVerified ? 'true' : 'false',
      a.adminVerified ? 'true' : 'false',
      a.featured ? 'true' : 'false',
      a.moderationHidden ? 'true' : 'false',
      a.averageRating.toStringAsFixed(2),
      '${a.totalReviews}',
      csvEscape(a.createdAt.toUtc().toIso8601String()),
    ].join(','));
  }
  return buf.toString();
}
