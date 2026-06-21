import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kover/generated/l10n/app_localizations.dart';
import 'package:kover/riverpod/providers/settings/credentials.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:kover/utils/layout_constants.dart';
import 'package:kover/widgets/util/async_value.dart';
import 'package:kover/widgets/util/sliver_bottom_padding.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CustomHeadersSheet extends ConsumerWidget {
  const CustomHeadersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final headers = ref.watch(
      credentialsProvider.select(
        (state) => state.whenData((value) => value.customHeaders),
      ),
    );

    return Async(
      asyncValue: headers,
      data: (data) {
        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: _AddHeaderForm(),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: LayoutConstants.largePadding),
            ),

            if (data.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LayoutConstants.mediumPadding,
                  vertical: LayoutConstants.smallPadding,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Text(
                        l.savedHeaders,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      TextButton.icon(
                        label: Text(l.clearAll),
                        icon: const Icon(KoverIcons.trash),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () async {
                          await ref
                              .read(credentialsProvider.notifier)
                              .removeAllHeaders();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SliverList.separated(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final entry = data.entries.elementAt(index);
                  return _HeaderListEntry(entry: entry);
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: LayoutConstants.mediumPadding),
              ),
            ],
            const SliverBottomPadding(),
          ],
        );
      },
    );
  }
}

class _HeaderListEntry extends ConsumerWidget {
  const _HeaderListEntry({
    required this.entry,
  });

  final MapEntry<String, String> entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card.filled(
      margin: const EdgeInsets.symmetric(
        horizontal: LayoutConstants.mediumPadding,
      ),
      child: ListTile(
        title: Text(entry.key),
        subtitle: Text(entry.value),
        trailing: IconButton(
          icon: Icon(
            KoverIcons.trash,
            color: Theme.of(context).colorScheme.error,
          ),
          onPressed: () async {
            await ref
                .read(credentialsProvider.notifier)
                .removeHeader(entry.key);
          },
        ),
      ),
    );
  }
}

class _AddHeaderForm extends HookConsumerWidget {
  const _AddHeaderForm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final keyController = useTextEditingController();
    final valueController = useTextEditingController();
    useListenable(keyController);
    useListenable(valueController);

    final canAdd =
        keyController.text.isNotEmpty && valueController.text.isNotEmpty;

    return Card.filled(
      margin: const EdgeInsets.symmetric(
        horizontal: LayoutConstants.mediumPadding,
      ),
      child: Padding(
        padding: const EdgeInsets.all(LayoutConstants.mediumPadding),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          spacing: LayoutConstants.mediumPadding,
          children: [
            TextField(
              controller: keyController,
              decoration: InputDecoration(labelText: l.headerName),
            ),
            TextField(
              controller: valueController,
              decoration: InputDecoration(labelText: l.headerValue),
            ),
            Row(
              mainAxisAlignment: .end,
              children: [
                FilledButton.icon(
                  label: Text(l.addHeader),
                  icon: const Icon(LucideIcons.plus),
                  onPressed: canAdd
                      ? () async {
                          await ref
                              .read(credentialsProvider.notifier)
                              .addHeader(
                                keyController.text,
                                valueController.text,
                              );
                          keyController.clear();
                          valueController.clear();
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
