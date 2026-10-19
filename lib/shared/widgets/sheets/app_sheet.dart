import 'package:flutter/material.dart';
import '../../../core/theme/appearance_theme.dart';
import '../../../core/theme/aptiqu_tokens.dart';

class AppSheetHeader extends StatelessWidget {
  final String title;
  final String closeLabel;
  const AppSheetHeader({
    super.key,
    required this.title,
    this.closeLabel = 'Close',
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: context.type.titleMedium),
          ),
        ),
        IconButton(
          tooltip: closeLabel,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

/// A bounded overlay surface that also reacts to system appearance changes.
class AppSheetSurface extends StatelessWidget {
  final WidgetBuilder builder;
  const AppSheetSurface({super.key, required this.builder});
  @override
  Widget build(BuildContext context) => AppearanceTheme(
    builder: (context) => Material(
      color: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: builder(context),
    ),
  );
}

Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (_) => AppSheetSurface(
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom) *
                .9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSheetHeader(title: title),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: builder(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
