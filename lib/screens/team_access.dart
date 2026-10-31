import 'package:flutter/material.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/models/store_member.dart';
import 'package:kisekae/screens/seller_gate_screen.dart';
import 'package:kisekae/screens/seller_invite.dart';
import 'package:kisekae/screens/send_invite.dart';
import 'package:kisekae/services/store.dart';
import 'package:kisekae/services/store_member_service.dart';

class TeamAccessScreen extends StatefulWidget {
  final int storeId;
  final String? myRole;

  const TeamAccessScreen({super.key, required this.storeId, this.myRole});

  @override
  State<TeamAccessScreen> createState() => _TeamAccessScreenState();
}

class _TeamAccessScreenState extends State<TeamAccessScreen> {
  final _repository = StoreMembers();

  String _myRole = '';
  List<StoreMember> _members = [];
  bool _loading = true;
  String? _error;
  int? _busyId;
  bool _leaving = false;

  bool get _isOwner => _myRole.toUpperCase() == 'OWNER';

  bool get _isManager => _myRole.toUpperCase() == 'MANAGER';

  @override
  void initState() {
    super.initState();
    _myRole = widget.myRole ?? '';
    _load();
  }

  void _showMessage(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red : Colors.green,
        ),
      );
  }

  Future<void> _resolveRole() async {
    try {
      final response = await StoreOperations().getStores(pageSize: 50);
      for (final store in response.results) {
        if (store.id == widget.storeId) {
          if (mounted) setState(() => _myRole = store.myRole);
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      if (_myRole.isEmpty) await _resolveRole();
      final members = await _repository.getMembers(widget.storeId);
      if (!mounted) return;
      members.sort((a, b) {
        if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
        return a.createdAt.compareTo(b.createdAt);
      });
      setState(() {
        _members = members;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load team members');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _runAction(
    StoreMember member,
    Future<void> Function() call,
    String successMessage,
  ) async {
    if (_busyId != null) return;
    setState(() => _busyId = member.id);
    try {
      await call();
      if (!mounted) return;
      _showMessage(successMessage);
      await _load(showSpinner: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message, error: true);
      if (e.statusCode == 400 || e.statusCode == 404) {
        _load(showSpinner: false);
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('Something went wrong. Please try again', error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _remove(StoreMember member) async {
    final confirmed = await _confirm(
      title: 'Remove member?',
      message:
          '${member.displayName} will lose access to this store and its products and orders.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;

    await _runAction(
      member,
      () => _repository.removeMember(widget.storeId, member.id),
      '${member.displayName} was removed',
    );
  }

  Future<void> _transferOwnership(StoreMember member) async {
    final confirmed = await _confirm(
      title: 'Transfer ownership?',
      message:
          '${member.displayName} will become the owner of this store. You will become a manager and will no longer be able to manage ownership.',
      confirmLabel: 'Transfer',
    );
    if (!confirmed || !mounted) return;

    await _runAction(member, () async {
      final store = await _repository.transferOwnership(
        widget.storeId,
        member.id,
      );
      if (mounted) {
        setState(
          () => _myRole = store.myRole.isNotEmpty ? store.myRole : 'MANAGER',
        );
      }
    }, 'Ownership transferred to ${member.displayName}');
  }

  List<StoreMember> get _transferCandidates =>
      _members.where((member) => member.isManager).toList();

  void _goToGate() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SellerGateScreen()),
      (route) => false,
    );
  }

  Future<void> _leaveStore() async {
    if (_leaving || _busyId != null) return;
    if (_isOwner) {
      await _leaveAsOwner();
    } else {
      await _leaveAsManager();
    }
  }

  Future<void> _leaveAsManager() async {
    final confirmed = await _confirm(
      title: 'Leave this store?',
      message: 'You will lose access to this store\'s products, orders and team. You can only rejoin if the owner invites you again.',
      confirmLabel: 'Leave',
    );
    if (!confirmed || !mounted) return;

    setState(() => _leaving = true);
    try {
      await _repository.leaveStore(widget.storeId);
      if (!mounted) return;
      _showMessage('You left the store');
      _goToGate();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Something went wrong. Please try again', error: true);
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  Future<void> _leaveAsOwner() async {
    final candidates = _transferCandidates;
    if (candidates.isEmpty) {
      await _showNoSuccessorDialog();
      return;
    }

    final newOwner = await _pickNewOwner(candidates);
    if (newOwner == null || !mounted) return;

    final confirmed = await _confirm(
      title: 'Transfer ownership and leave?',
      message:
          '${newOwner.displayName} will become the owner of this store and you will leave it. You will lose access to its products, orders and team.',
      confirmLabel: 'Transfer & leave',
    );
    if (!confirmed || !mounted) return;

    setState(() => _leaving = true);
    var transferred = false;
    try {
      await _repository.transferOwnership(widget.storeId, newOwner.id);
      transferred = true;
      await _repository.leaveStore(widget.storeId);
      if (!mounted) return;
      _showMessage('Ownership transferred and you left the store');
      _goToGate();
    } on ApiException catch (e) {
      _onOwnerLeaveFailed(e.message, transferred);
    } catch (_) {
      _onOwnerLeaveFailed(
        'Something went wrong. Please try again',
        transferred,
      );
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  void _onOwnerLeaveFailed(String message, bool transferred) {
    if (!mounted) return;
    if (transferred) {
      setState(() => _myRole = 'MANAGER');
      _showMessage(
        'Ownership was transferred, but leaving failed: $message. You can leave from this screen.',
        error: true,
      );
      _load(showSpinner: false);
    } else {
      _showMessage(message, error: true);
    }
  }

  Future<void> _showNoSuccessorDialog() async {
    final invite = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer ownership first'),
        content: const Text(
          'As the owner, you can\'t leave until another member takes over. You don\'t have any managers yet. Invite someone, and once they join you can transfer ownership and leave.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Invite members'),
          ),
        ],
      ),
    );
    if (invite == true && mounted) _openSendInvite();
  }

  Future<StoreMember?> _pickNewOwner(List<StoreMember> candidates) {
    StoreMember? selected;

    return showDialog<StoreMember>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Choose the new owner'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final member in candidates)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        selected?.id == member.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: cs.primary,
                      ),
                      title: Text(member.displayName),
                      subtitle:
                          member.email.isNotEmpty &&
                              member.email != member.displayName
                          ? Text(member.email)
                          : null,
                      onTap: () => setDialogState(() => selected = member),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(ctx, selected),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openSendInvite() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SendInviteScreen(storeId: widget.storeId),
      ),
    );
  }

  void _openSentInvites() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvitesScreen(storeId: widget.storeId)),
    );
  }

  Widget _membersSection(ColorScheme cs) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: cs.onSurface),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _load,
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.primary,
                side: BorderSide(color: cs.primary),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_members.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No team members found',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: cs.onSurface.withOpacity(0.7)),
        ),
      );
    }

    return Column(
      children: _members.map((member) {
        final bool actionable = _isOwner && member.isManager;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _MemberCard(
            member: member,
            showActions: actionable,
            busy: _busyId == member.id,
            disabled: _busyId != null || _leaving,
            onRemove: () => _remove(member),
            onTransfer: () => _transferOwnership(member),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surface,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cs.onSurface, width: 2),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: cs.onSurface,
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Team Access',
          style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: cs.primary,
          onRefresh: () => _load(showSpinner: false),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Center(child: _TeamIllustration()),
              const SizedBox(height: 16),
              Text(
                'Manage Your Team',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Add team members to help you manage\nyour store , products and orders',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: cs.onSurface),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: _openSendInvite,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Invite members'),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Team members',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _openSentInvites,
                    style: TextButton.styleFrom(
                      foregroundColor: cs.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Sent invites'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _membersSection(cs),
              if ((_isOwner || _isManager) && !_loading) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _leaving ? null : _leaveStore,
                    icon: _leaving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: cs.error,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.logout, size: 20),
                    label: const Text('Leave store'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (_isOwner)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'As the owner, you will choose a new owner before leaving.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.65),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final StoreMember member;
  final bool showActions;
  final bool busy;
  final bool disabled;
  final VoidCallback onRemove;
  final VoidCallback onTransfer;

  const _MemberCard({
    required this.member,
    required this.showActions,
    required this.busy,
    required this.disabled,
    required this.onRemove,
    required this.onTransfer,
  });

  static const _palette = [
    Color(0xFF1B6B35),
    Color(0xFF1A2B6B),
    Color(0xFF7D2938),
    Color(0xFF00695C),
    Color(0xFF5E35B1),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatarColor = _palette[member.id.abs() % _palette.length];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6EF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, 3),
            blurRadius: 8,
            color: Color(0x1F000000),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarColor,
            ),
            child: Text(
              member.initials,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member.roleLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: cs.primary,
                strokeWidth: 2,
              ),
            )
          else if (showActions)
            PopupMenuButton<String>(
              enabled: !disabled,
              icon: Icon(Icons.more_vert, color: cs.primary),
              onSelected: (value) {
                if (value == 'transfer') onTransfer();
                if (value == 'remove') onRemove();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'transfer',
                  child: Text('Transfer ownership'),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Text(
                    'Remove from store',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TeamIllustration extends StatelessWidget {
  const _TeamIllustration();

  static const _left = Color(0xFF6B1F2E);
  static const _center = Color(0xFF7D2938);
  static const _right = Color(0xFF3E1219);

  Widget _head(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _body(double width, double height, Color color, double topRadius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(topRadius),
          topRight: Radius.circular(topRadius),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 112,
      child: Stack(
        children: [
          Positioned(left: 4, top: 22, child: _head(32, _left)),
          Positioned(right: 4, top: 22, child: _head(32, _right)),
          Positioned(left: 0, bottom: 4, child: _body(58, 58, _left, 28)),
          Positioned(right: 0, bottom: 4, child: _body(58, 58, _right, 28)),
          Positioned(left: 56, top: 0, child: _head(38, _center)),
          Positioned(left: 48, bottom: 0, child: _body(54, 62, _center, 22)),
        ],
      ),
    );
  }
}
