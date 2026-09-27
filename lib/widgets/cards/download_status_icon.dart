import 'package:kover/models/download_status.dart';
import 'package:kover/utils/constants/kover_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kover/utils/layout_constants.dart';

/// A small icon overlay that conveys the download state of a chapter, volume,
/// or series.
///
/// - **Downloading** (`isDownloading == true`): shows a `CircularProgressIndicator`.
///   When [progress] is non-null the indicator is determinate (0.0–1.0);
///   otherwise it spins indeterminately.
/// - **Downloaded** (`isDownloaded == true`): shows a static download icon.
/// - **Neither**: renders nothing (`null`-safe; returns `SizedBox.shrink()`).
class DownloadStatusIcon extends StatelessWidget {
  final DownloadStatus? status;

  const DownloadStatusIcon({
    super.key,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.secondary;

    final content = status!.when(
      queued: () => Icon(
        KoverIcons.queued,
        color: iconColor,
        size: LayoutConstants.smallIcon,
      ),
      downloading: (progress) => SizedBox.square(
        dimension: LayoutConstants.smallIcon,
        child: CircularProgressIndicator(value: progress),
      ),
      downloaded: () => Icon(
        KoverIcons.download,
        color: iconColor,
        size: LayoutConstants.smallIcon,
      ),
    );

    return Card(
      child: Padding(
        padding: LayoutConstants.smallEdgeInsets,
        child: content,
      ),
    );
  }
}
