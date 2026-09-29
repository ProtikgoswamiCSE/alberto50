import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Movie artwork. Uses the browser/image decoder directly so posters show
/// on web and TV, where the disk cache often paints a blank card.
class PosterImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final Alignment alignment;

  const PosterImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return const _PosterFallback();
    }

    return Image.network(
      imageUrl,
      fit: fit,
      alignment: alignment,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(
          color: AppTheme.bgElevated,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accent,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stack) => const _PosterFallback(),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppTheme.bgElevated,
      child: Center(
        child: Icon(Icons.movie_rounded, color: AppTheme.textMuted, size: 40),
      ),
    );
  }
}
