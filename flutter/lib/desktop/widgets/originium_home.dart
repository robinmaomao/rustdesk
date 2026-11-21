import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/originium_transfer_registry.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';

/// UU-style local device card.
///
/// The device id and the password are the two things a user reads out loud when
/// pairing, so they get the visual weight here instead of the small board rows
/// RustDesk originally used.
///
/// [onOpenSettings] and [onChangePassword] are injected by the home page so this
/// widget does not need to import the settings page (which imports the home
/// page, and would create an import cycle).
class OriginiumIdCard extends StatelessWidget {
  const OriginiumIdCard(
      {super.key, this.onOpenSettings, this.onChangePassword});

  final VoidCallback? onOpenSettings;
  final VoidCallback? onChangePassword;

  @override
  Widget build(BuildContext context) {
    final model = gFFI.serverModel;
    // ServerModel is a ChangeNotifier; rebuilding on notify keeps the password
    // label and the refresh action in sync with the verification settings.
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) => _buildCard(context, model),
    );
  }

  Widget _buildCard(BuildContext context, ServerModel model) {
    final textTheme = Theme.of(context).textTheme;
    final labelColor =
        textTheme.titleLarge?.color?.withOpacity(0.55) ?? Colors.grey;
    final borderColor = MyTheme.color(context).border!;
    // Same rule the original password board used: a one-time password only
    // exists when neither click-approval nor a permanent password is in use.
    final showOneTime = model.approveMode != 'click' &&
        model.verificationMethod != kUsePermanentPassword;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(translate('ID'),
                  style: TextStyle(fontSize: 13, color: labelColor)),
              const Spacer(),
              if (onOpenSettings != null)
                IconButton(
                  tooltip: translate('Settings'),
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
              _CopyAction(
                tooltip: translate('Copy'),
                onCopy: () => _copy(model.serverId.text),
              ),
            ],
          ),
          TextFormField(
            controller: model.serverId,
            readOnly: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
            ),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ).workaroundFreezeLinuxMint(),
          const SizedBox(height: 10),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                showOneTime
                    ? translate('One-time Password')
                    : translate('Permanent Password'),
                style: TextStyle(fontSize: 13, color: labelColor),
              ),
              const Spacer(),
              if (onChangePassword != null)
                IconButton(
                  tooltip: translate('Change Password'),
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: onChangePassword,
                  icon: const Icon(Icons.edit_outlined),
                ),
              _CopyAction(
                tooltip: translate('Copy'),
                onCopy: () => _copy(model.serverPasswd.text),
              ),
              if (showOneTime)
                IconButton(
                  tooltip: translate('Refresh Password'),
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: () => bind.mainUpdateTemporaryPassword(),
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          TextFormField(
            controller: model.serverPasswd,
            readOnly: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
            ),
            style: const TextStyle(fontSize: 17, letterSpacing: 1.0),
          ).workaroundFreezeLinuxMint(),
        ],
      ),
    );
  }

  void _copy(String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    showToast(translate('Copied'));
  }
}

class _CopyAction extends StatelessWidget {
  const _CopyAction({required this.tooltip, required this.onCopy});

  final String tooltip;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      onPressed: onCopy,
      icon: const Icon(Icons.content_copy),
    );
  }
}

/// Small uppercase section label used to separate the home page areas.
class OriginiumSectionHeader extends StatelessWidget {
  const OriginiumSectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
              color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withOpacity(0.6) ??
                  Colors.grey,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

IconData originiumPlatformIcon(String platform) {
  switch (platform.toLowerCase()) {
    case 'windows':
      return Icons.desktop_windows_outlined;
    case 'mac os':
    case 'macos':
      return Icons.laptop_mac_outlined;
    case 'linux':
      return Icons.computer_outlined;
    case 'android':
      return Icons.phone_android_outlined;
    case 'ios':
      return Icons.phone_iphone_outlined;
    default:
      return Icons.devices_other_outlined;
  }
}

/// Compact device tile: status, name, id and the two primary actions.
///
/// This intentionally drops the certificate/tag rows that the full RustDesk
/// peer card shows, so a grid of devices stays scannable.
class OriginiumPeerTile extends StatefulWidget {
  const OriginiumPeerTile({
    super.key,
    required this.peer,
    this.onConnect,
    this.onFileTransfer,
  });

  final Peer peer;
  final VoidCallback? onConnect;
  final VoidCallback? onFileTransfer;

  @override
  State<OriginiumPeerTile> createState() => _OriginiumPeerTileState();
}

class _OriginiumPeerTileState extends State<OriginiumPeerTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final peer = widget.peer;
    final textTheme = Theme.of(context).textTheme;
    final displayName = peer.alias.isNotEmpty
        ? peer.alias
        : (peer.hostname.isNotEmpty ? peer.hostname : peer.id);
    final online = peer.online;
    final accent = MyTheme.accent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hover
                ? accent.withOpacity(0.55)
                : MyTheme.color(context).border!,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(originiumPlatformIcon(peer.platform),
                    size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: online
                        ? (MyTheme.color(context).me ?? accent)
                        : Colors.grey.withOpacity(0.5),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                peer.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TileAction(
                    label: translate('Connect'),
                    icon: Icons.play_arrow_rounded,
                    filled: true,
                    onTap: widget.onConnect,
                  ),
                ),
                const SizedBox(width: 6),
                // Both actions must stay Expanded: `_TileAction` relies on a
                // bounded width, otherwise its label collapses to zero width.
                Expanded(
                  child: _TileAction(
                    label: translate('File Transfer'),
                    icon: Icons.swap_horiz_rounded,
                    onTap: widget.onFileTransfer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TileAction extends StatelessWidget {
  const _TileAction({
    required this.label,
    required this.icon,
    this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final enabled = onTap != null;
    final accent = MyTheme.accent;
    final color = filled
        ? Colors.white
        : (textTheme.bodyMedium?.color ?? Colors.white)
            .withOpacity(enabled ? 0.85 : 0.35);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border:
              filled ? null : Border.all(color: MyTheme.color(context).border!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slim progress strip shown while file transfers keep running in the
/// background, i.e. after the transfer window was minimised.
class OriginiumTransferBanner extends StatefulWidget {
  const OriginiumTransferBanner({super.key});

  @override
  State<OriginiumTransferBanner> createState() =>
      _OriginiumTransferBannerState();
}

class _OriginiumTransferBannerState extends State<OriginiumTransferBanner> {
  Timer? _timer;
  String _lastSnapshot = '';

  @override
  void initState() {
    super.initState();
    // Job state lives in a mutable model, not an observable, so poll while the
    // strip is mounted instead of wiring listeners into every job controller.
    // The tick only rebuilds when the projected state actually changed, which
    // keeps an idle home page from rebuilding once a second.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final registry = OriginiumTransferRegistry.instance;
    final snapshot = '${registry.activeCount}|${registry.percentText}';
    if (snapshot == _lastSnapshot) return;
    _lastSnapshot = snapshot;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final registry = OriginiumTransferRegistry.instance;
    if (!registry.hasActiveTransfers) return const SizedBox.shrink();
    final muted =
        Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.65);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MyTheme.color(context).border!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${translate('Transfer in progress')}: ${registry.activeCount}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Text(registry.percentText,
                  style: TextStyle(fontSize: 12, color: muted)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: registry.percent,
              minHeight: 5,
              backgroundColor: MyTheme.accent.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid of recently used devices, styled after the UU remote device list.
class OriginiumDeviceGrid extends StatefulWidget {
  const OriginiumDeviceGrid({super.key, this.maxTiles = 8});

  final int maxTiles;

  @override
  State<OriginiumDeviceGrid> createState() => _OriginiumDeviceGridState();
}

class _OriginiumDeviceGridState extends State<OriginiumDeviceGrid> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await bind.mainLoadRecentPeers();
      } catch (e) {
        debugPrint('load recent peers failed: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = gFFI.recentPeersModel;
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        final peers = model.peers
            .where((peer) => peer.id.isNotEmpty)
            .take(widget.maxTiles)
            .toList(growable: false);
        if (peers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
            child: Text(
              translate('No recent sessions'),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withOpacity(0.6),
              ),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 560
                    ? 2
                    : 1;
            const spacing = 10.0;
            final tileWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            // Fixed height keeps rows aligned, but it has to follow the user's
            // text scale or the content overflows the tile.
            final tileHeight = 128.0 *
                MediaQuery.textScalerOf(context)
                    .scale(1.0)
                    .clamp(1.0, 1.5)
                    .toDouble();
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final peer in peers)
                  SizedBox(
                    width: tileWidth,
                    height: tileHeight,
                    child: OriginiumPeerTile(
                      peer: peer,
                      // Route through connect() rather than connectMainDesktop()
                      // so relay ids are resolved and forceRelay is applied.
                      onConnect: () => connect(context, peer.id),
                      onFileTransfer: () =>
                          connect(context, peer.id, isFileTransfer: true),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
