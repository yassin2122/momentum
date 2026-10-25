import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// A cached network photo that shows up with no visible delay.
///
/// - Disk cache: the package default keeps only 200 files for 30 days, so a
///   big exercise library keeps evicting and re-downloading photos. Ours
///   keeps 3000 for 90 days.
/// - No fades: a photo already on disk swaps in on the next frame instead of
///   fading in, so it never looks like it's loading.
/// - Decodes at [cacheWidth] pixels (when given) instead of full size, and
///   shares its image key with [precache], so a precached photo paints on
///   the first frame.
class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto({
    required this.url,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
    super.key,
  });

  final String url;

  /// Shown while loading and when the photo can't load.
  final Widget placeholder;
  final BoxFit fit;
  final Alignment alignment;

  /// Decode width in physical pixels; null decodes at full size.
  final int? cacheWidth;

  /// Shared disk cache for every app photo.
  static final CacheManager cacheManager = CacheManager(Config(
    'gritPhotos',
    stalePeriod: const Duration(days: 90),
    maxNrOfCacheObjects: 3000,
  ));

  /// The image key [NetworkPhoto] paints with — the same one
  /// `CachedNetworkImage` builds from `memCacheWidth`.
  static ImageProvider provider(String url, {int? cacheWidth}) =>
      ResizeImage.resizeIfNeeded(
        cacheWidth,
        null,
        CachedNetworkImageProvider(url, cacheManager: cacheManager),
      );

  /// Starts downloading and decoding [urls] in the background so they're
  /// ready before they're shown. Failures are ignored (the widget shows its
  /// placeholder instead).
  static void precache(
    BuildContext context,
    Iterable<String> urls, {
    int? cacheWidth,
  }) {
    for (final url in urls) {
      precacheImage(
        provider(url, cacheWidth: cacheWidth),
        context,
        onError: (_, __) {},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: cacheManager,
      fit: fit,
      alignment: alignment,
      memCacheWidth: cacheWidth,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}
