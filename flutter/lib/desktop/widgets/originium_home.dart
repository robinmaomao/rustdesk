import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart';
import 'package:flutter_hbb/models/originium_transfer_registry.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';

/// Shared metrics so the cards, tiles and controls keep one rhythm instead of
/// each widget picking its own radius and gap.
const double _kOriginiumCardRadius = 14;
const double _kOriginiumControlRadius = 9;
const double _kOriginiumGap = 10;

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
        borderRadius: BorderRadius.circular(_kOriginiumCardRadius),
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
            onTap: () => _copy(model.serverId.text),
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
            onTap: () => _copy(model.serverPasswd.text),
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

/// One entry of the device grid, tagged with where it came from.
class _DeviceEntry {
  const _DeviceEntry(this.peer, {this.favorite = false, this.lan = false});

  final Peer peer;
  final bool favorite;
  final bool lan;
}

/// Compact device tile: platform avatar with status badge, name, id and the two
/// primary actions. Secondary actions live in the hover menu so the tile stays
/// scannable.
class OriginiumPeerTile extends StatefulWidget {
  const OriginiumPeerTile({
    super.key,
    required this.peer,
    this.favorite = false,
    this.lan = false,
    this.onConnect,
    this.onFileTransfer,
    this.onRemove,
  });

  final Peer peer;
  final bool favorite;
  final bool lan;
  final VoidCallback? onConnect;
  final VoidCallback? onFileTransfer;
  final VoidCallback? onRemove;

  @override
  State<OriginiumPeerTile> createState() => _OriginiumPeerTileState();
}

class _OriginiumPeerTileState extends State<OriginiumPeerTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final peer = widget.peer;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final accent = MyTheme.accent;
    final displayName = peer.alias.isNotEmpty
        ? peer.alias
        : (peer.hostname.isNotEmpty ? peer.hostname : peer.id);
    final online = peer.online;
    final statusColor = online
        ? (MyTheme.color(context).me ?? accent)
        : (textTheme.bodySmall?.color?.withOpacity(0.35) ?? Colors.grey);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(_kOriginiumCardRadius),
          border: Border.all(
            color: _hover
                ? accent.withOpacity(0.55)
                : MyTheme.color(context).border!,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PlatformAvatar(
                  platform: peer.platform,
                  statusColor: statusColor,
                  badgeBorder: theme.cardColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          if (widget.favorite)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.star,
                                  size: 11, color: Colors.amber[600]),
                            ),
                          if (widget.lan)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.wifi,
                                  size: 11, color: accent.withOpacity(0.8)),
                            ),
                          Expanded(
                            child: Text(
                              peer.id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: textTheme.bodySmall?.color
                                    ?.withOpacity(0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: _hover ? 1 : 0,
                  duration: const Duration(milliseconds: 120),
                  child: IgnorePointer(
                    ignoring: !_hover,
                    child: _DeviceMenu(
                      onCopyId: () => _copyId(peer),
                      onSetAlias: () => _setAlias(context, peer),
                      onRemove: widget.onRemove,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
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

  void _copyId(Peer peer) {
    Clipboard.setData(ClipboardData(text: peer.id));
    showToast(translate('Copied'));
  }

  Future<void> _setAlias(BuildContext context, Peer peer) async {
    final controller = TextEditingController(text: peer.alias);
    final alias = await showDialog<String>(
      context: context,
      builder: (dialogContext) => CustomAlertDialog(
        title: Text(translate('Alias')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(isDense: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(translate('Cancel')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(translate('OK')),
          ),
        ],
      ),
    );
    if (alias == null) return;
    try {
      await bind.mainSetPeerAlias(id: peer.id, alias: alias);
      await bind.mainLoadRecentPeers();
      await bind.mainLoadFavPeers();
    } catch (e) {
      debugPrint('set alias failed: $e');
      showToast(translate('Failed'));
    }
  }
}

class _PlatformAvatar extends StatelessWidget {
  const _PlatformAvatar({
    required this.platform,
    required this.statusColor,
    required this.badgeBorder,
  });

  final String platform;
  final Color statusColor;
  final Color badgeBorder;

  @override
  Widget build(BuildContext context) {
    final accent = MyTheme.accent;
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(_kOriginiumControlRadius),
            ),
            child:
                Icon(originiumPlatformIcon(platform), size: 20, color: accent),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                border: Border.all(color: badgeBorder, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceMenu extends StatelessWidget {
  const _DeviceMenu({
    required this.onCopyId,
    required this.onSetAlias,
    this.onRemove,
  });

  final VoidCallback onCopyId;
  final VoidCallback onSetAlias;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      padding: EdgeInsets.zero,
      iconSize: 18,
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'copy') onCopyId();
        if (value == 'alias') onSetAlias();
        if (value == 'remove') onRemove?.call();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'copy',
          child: Text(translate('Copy ID')),
        ),
        PopupMenuItem(
          value: 'alias',
          child: Text(translate('Set alias')),
        ),
        if (onRemove != null)
          PopupMenuItem(
            value: 'remove',
            child: Text(translate('Remove')),
          ),
      ],
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
      borderRadius: BorderRadius.circular(_kOriginiumControlRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(_kOriginiumControlRadius),
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
  bool _wasActive = false;

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
    final active = registry.hasActiveTransfers;
    if (_wasActive && !active) {
      // Last job of the queue finished while the strip was visible.
      showToast(translate('Transfer finished'));
    }
    _wasActive = active;
    final snapshot = '$active|${registry.activeCount}|${registry.percentText}'
        '|${registry.speedBytesPerSecond.round()}';
    if (snapshot == _lastSnapshot) return;
    _lastSnapshot = snapshot;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final registry = OriginiumTransferRegistry.instance;
    if (!registry.hasActiveTransfers) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.color?.withOpacity(0.65);
    final eta = registry.eta;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(_kOriginiumCardRadius),
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
                  '${translate('Transfer in progress')}: ${registry.activeCount}'
                  ' · ${readableFileSize(registry.speedBytesPerSecond)}/s'
                  '${eta == null ? '' : ' · ${_formatEta(eta)}'}',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(registry.percentText,
                  style: TextStyle(fontSize: 12, color: muted)),
              IconButton(
                tooltip: translate('File Transfer'),
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                onPressed: () => rustDeskWinManager.showFileTransferWindows(),
                icon: const Icon(Icons.open_in_new),
              ),
              IconButton(
                tooltip: translate('Cancel'),
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                onPressed: () => OriginiumTransferRegistry.instance.cancelAll(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: registry.percent,
                minHeight: 5,
                backgroundColor: MyTheme.accent.withOpacity(0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatEta(Duration eta) {
    final minutes = eta.inMinutes;
    if (minutes >= 60) {
      return '${eta.inHours}h${eta.inMinutes % 60}m';
    }
    if (minutes >= 1) {
      return '${minutes}m${eta.inSeconds % 60}s';
    }
    return '${eta.inSeconds}s';
  }
}

/// Collapsible "My Devices" shelf for the connection page.
class OriginiumDeviceShelf extends StatefulWidget {
  const OriginiumDeviceShelf({super.key, this.maxTiles = 6});

  final int maxTiles;

  @override
  State<OriginiumDeviceShelf> createState() => _OriginiumDeviceShelfState();
}

class _OriginiumDeviceShelfState extends State<OriginiumDeviceShelf> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ConstrainedBox(
        // Keeps the shelf from pushing the connect box off-screen when the
        // window is narrow and the grid falls back to one column.
        constraints: const BoxConstraints(maxHeight: 320),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OriginiumSectionHeader(
                translate('My Devices'),
                trailing: IconButton(
                  tooltip:
                      _collapsed ? translate('Expand') : translate('Collapse'),
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: () => setState(() => _collapsed = !_collapsed),
                  icon:
                      Icon(_collapsed ? Icons.expand_more : Icons.expand_less),
                ),
              ),
              const OriginiumTransferBanner(),
              if (!_collapsed) OriginiumDeviceGrid(maxTiles: widget.maxTiles),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid of known devices: favourites first, then recent sessions, then LAN
/// discoveries, de-duplicated by id.
class OriginiumDeviceGrid extends StatefulWidget {
  const OriginiumDeviceGrid({super.key, this.maxTiles = 8});

  final int maxTiles;

  @override
  State<OriginiumDeviceGrid> createState() => _OriginiumDeviceGridState();
}

class _OriginiumDeviceGridState extends State<OriginiumDeviceGrid> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_reload);
  }

  Future<void> _reload({bool discover = false}) async {
    try {
      if (discover) await bind.mainDiscover();
      await Future.wait<void>([
        bind.mainLoadRecentPeers(),
        bind.mainLoadFavPeers(),
        bind.mainLoadLanPeers(),
      ]);
    } catch (e) {
      debugPrint('load devices failed: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  List<_DeviceEntry> _merge() {
    final seen = <String>{};
    final entries = <_DeviceEntry>[];
    void add(Peer peer, {bool favorite = false, bool lan = false}) {
      if (peer.id.isEmpty) return;
      if (!seen.add(peer.id)) return;
      entries.add(_DeviceEntry(peer, favorite: favorite, lan: lan));
    }

    for (final peer in gFFI.favoritePeersModel.peers) {
      add(peer, favorite: true);
    }
    for (final peer in gFFI.recentPeersModel.peers) {
      add(peer);
    }
    for (final peer in gFFI.lanPeersModel.peers) {
      add(peer, lan: true);
    }
    return entries.take(widget.maxTiles).toList(growable: false);
  }

  void _confirmRemove(_DeviceEntry entry) {
    final name = entry.peer.alias.isNotEmpty
        ? entry.peer.alias
        : formatID(entry.peer.id);
    deleteConfirmDialog(
        () => _remove(entry), '${translate('Remove')} "$name"?');
  }

  Future<void> _remove(_DeviceEntry entry) async {
    try {
      // Each list owns its own storage, so the entry has to be removed from the
      // one it actually came from.
      if (entry.favorite) {
        final favs = (await bind.mainGetFav()).toList();
        if (favs.remove(entry.peer.id)) {
          await bind.mainStoreFav(favs: favs);
        }
        await bind.mainLoadFavPeers();
      } else if (entry.lan) {
        await bind.mainRemoveDiscovered(id: entry.peer.id);
        await bind.mainLoadLanPeers();
      } else {
        await bind.mainRemovePeer(id: entry.peer.id);
        await bind.mainLoadRecentPeers();
      }
    } catch (e) {
      debugPrint('remove peer failed: $e');
      showToast(translate('Failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final listenable = Listenable.merge([
      gFFI.favoritePeersModel,
      gFFI.recentPeersModel,
      gFFI.lanPeersModel,
    ]);
    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) {
        final entries = _merge();
        if (entries.isEmpty) {
          return _EmptyDevices(
            loading: _loading,
            onScan: () => _reload(discover: true),
            onRefresh: _reload,
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 560
                    ? 2
                    : 1;
            const spacing = _kOriginiumGap;
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
                for (final entry in entries)
                  SizedBox(
                    width: tileWidth,
                    height: tileHeight,
                    child: OriginiumPeerTile(
                      peer: entry.peer,
                      favorite: entry.favorite,
                      lan: entry.lan,
                      // Route through connect() rather than connectMainDesktop()
                      // so relay ids are resolved and forceRelay is applied.
                      onConnect: () => connect(context, entry.peer.id),
                      onFileTransfer: () =>
                          connect(context, entry.peer.id, isFileTransfer: true),
                      onRemove: () => _confirmRemove(entry),
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

class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices({
    required this.loading,
    required this.onScan,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onScan;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.65);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(_kOriginiumCardRadius),
        border: Border.all(color: MyTheme.color(context).border!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.devices_other_outlined,
                size: 26, color: muted ?? Colors.grey),
          const SizedBox(height: 8),
          Text(
            translate('No recent sessions'),
            style: TextStyle(fontSize: 13, color: muted),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.radar, size: 16),
                label: Text(translate('Scan LAN')),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(translate('Refresh')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
