import 'package:flutter/material.dart';

enum TopicIconType {
  currentTopic,
  topic,
  subtopic,
}

/// High-performance topic & subtopic icon badge using optimized local WebP assets.
/// Automatically decodes at target pixel density (via cacheWidth/cacheHeight) to
/// prevent memory bloat and frame drops during panning/scrolling.
class TopicIcon extends StatelessWidget {
  final TopicIconType type;
  final double size;
  final bool decorative;

  static const String currentTopicAsset =
      'assets/images/topics/01_current_topic_play.webp';
  static const String topicAsset =
      'assets/images/topics/02_topic.webp';
  static const String subtopicAsset =
      'assets/images/topics/03_subtopic.webp';

  const TopicIcon({
    super.key,
    required this.type,
    this.size = 54,
    this.decorative = true,
  });

  /// Asynchronously primes topic icons into Flutter's ImageCache to eliminate
  /// decode latency on first render.
  static void precacheIcons(BuildContext context) {
    precacheImage(const AssetImage(currentTopicAsset), context);
    precacheImage(const AssetImage(topicAsset), context);
    precacheImage(const AssetImage(subtopicAsset), context);
  }

  String get assetPath {
    switch (type) {
      case TopicIconType.currentTopic:
        return currentTopicAsset;
      case TopicIconType.topic:
        return topicAsset;
      case TopicIconType.subtopic:
        return subtopicAsset;
    }
  }

  IconData get fallbackIcon {
    switch (type) {
      case TopicIconType.currentTopic:
        return Icons.play_arrow_rounded;
      case TopicIconType.topic:
        return Icons.menu_book_rounded;
      case TopicIconType.subtopic:
        return Icons.menu_book_outlined;
    }
  }

  String get semanticLabel {
    switch (type) {
      case TopicIconType.currentTopic:
        return 'Current topic';
      case TopicIconType.topic:
        return 'Topic';
      case TopicIconType.subtopic:
        return 'Subtopic';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final pixels = (size * dpr).ceil().clamp(1, 1024);

    return Semantics(
      label: decorative ? null : semanticLabel,
      excludeSemantics: decorative,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: pixels,
        cacheHeight: pixels,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Icon(
              fallbackIcon,
              size: size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
