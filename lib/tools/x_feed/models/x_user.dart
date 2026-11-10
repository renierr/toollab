class XUser {
  final String id;
  final String name;
  final String screenName;
  final String? avatarUrl;
  final bool verified;
  final String? bio;
  final String? bannerUrl;
  final int? followers;
  final int? following;
  final int? postCount;

  const XUser({
    required this.id,
    required this.name,
    required this.screenName,
    this.avatarUrl,
    this.verified = false,
    this.bio,
    this.bannerUrl,
    this.followers,
    this.following,
    this.postCount,
  });

  /// X serves 48px avatars as `_normal`.
  String? get largeAvatarUrl =>
      avatarUrl?.replaceFirst('_normal.', '_400x400.');

  String get profileUrl => 'https://x.com/$screenName';
}
