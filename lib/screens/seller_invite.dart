import 'package:flutter/material.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/api_exception.dart';
import 'package:kisekae/models/invite.dart';
import 'package:kisekae/screens/send_invite.dart';
import 'package:kisekae/services/seller_invitation.dart';

class InvitesScreen extends StatefulWidget {
  final int storeId;

  const InvitesScreen({super.key, required this.storeId});

  @override
  State<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends State<InvitesScreen> {
  static const Map<String, String?> _filters = {
    'All': null,
    'Pending': 'PENDING',
    'Accepted': 'ACCEPTED',
    'Declined': 'DECLINED',
    'Expired': 'EXPIRED',
    'Revoked': 'REVOKED',
  };

  final _repository = StoreInvites();

  List<SellerInvitation> _invites = [];
  String? _status;
  bool _loading = true;
  String? _error;
  int? _busyId;
  String? _busyAction;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _showMessage(String text, {bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            style: TextStyle(
              color: error
                  ? scheme.onError
                  : (isDark ? Colors.black : Colors.white),
            ),
          ),
          backgroundColor: error ? scheme.error : context.appColors.success,
        ),
      );
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final invites = await _repository.getInvites(
        widget.storeId,
        status: _status,
      );
      if (!mounted) return;
      setState(() {
        _invites = invites;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load invitations');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeFilter(String? status) {
    if (status == _status) return;
    setState(() => _status = status);
    _load();
  }

  Future<void> _openSendInvite() async {
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SendInviteScreen(storeId: widget.storeId),
      ),
    );
    if (sent == true && mounted) _load(showSpinner: false);
  }

  Future<void> _runAction(
    SellerInvitation invite,
    String action,
    Future<void> Function() call,
    String successMessage,
  ) async {
    if (_busyId != null) return;
    setState(() {
      _busyId = invite.id;
      _busyAction = action;
    });
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
      if (mounted) {
        setState(() {
          _busyId = null;
          _busyAction = null;
        });
      }
    }
  }

  Future<void> _resend(SellerInvitation invite) {
    return _runAction(invite, 'resend', () async {
      await _repository.resendInvite(widget.storeId, invite.id);
    }, 'Invitation resent to ${invite.email}');
  }

  Future<void> _revoke(SellerInvitation invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke invitation?'),
        content: Text(
          '${invite.email} will no longer be able to accept this invitation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runAction(
      invite,
      'revoke',
      () => _repository.revokeInvite(widget.storeId, invite.id),
      'Invitation revoked',
    );
  }

  Widget _centered(List<Widget> children) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        ...children,
      ],
    );
  }

  Widget _filterBar(ColorScheme cs) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _filters.entries.map((entry) {
          final selected = entry.value == _status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.key),
              selected: selected,
              showCheckmark: false,
              onSelected: _loading ? null : (_) => _changeFilter(entry.value),
              selectedColor: cs.primary,
              backgroundColor: context.appColors.card,
              side: BorderSide(
                color: selected ? cs.primary : context.appColors.border,
              ),
              labelStyle: TextStyle(
                color: selected ? cs.onPrimary : cs.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _body(ColorScheme cs) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    if (_error != null) {
      return _centered([
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: cs.onSurface),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton(
            onPressed: _load,
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.primary,
              side: BorderSide(color: cs.primary),
            ),
            child: const Text('Retry'),
          ),
        ),
      ]);
    }

    if (_invites.isEmpty) {
      return _centered([
        Icon(
          Icons.mail_outline,
          size: 56,
          color: cs.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 16),
        Text(
          _status == null ? 'No invitations yet' : 'No invitations here',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Invite people to help you manage this store.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ]);
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _invites.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final invite = _invites[index];
        final bool busy = _busyId == invite.id;
        return _InviteCard(
          invite: invite,
          disabled: _busyId != null,
          resendLoading: busy && _busyAction == 'resend',
          revokeLoading: busy && _busyAction == 'revoke',
          onResend: () => _resend(invite),
          onRevoke: () => _revoke(invite),
        );
      },
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
          'Invites',
          style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 4),
            _filterBar(cs),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                color: cs.primary,
                onRefresh: () => _load(showSpinner: false),
                child: _body(cs),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _openSendInvite,
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                  label: const Text('Invite'),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final SellerInvitation invite;
  final bool disabled;
  final bool resendLoading;
  final bool revokeLoading;
  final VoidCallback onResend;
  final VoidCallback onRevoke;

  const _InviteCard({
    required this.invite,
    required this.disabled,
    required this.resendLoading,
    required this.revokeLoading,
    required this.onResend,
    required this.onRevoke,
  });

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  String _dateLine() {
    final sent = 'Sent ${_formatDate(invite.createdAt)}';
    final expires = invite.expiresAt;
    if (invite.status == 'PENDING' && expires != null) {
      return '$sent  •  Expires ${_formatDate(expires)}';
    }
    final responded = invite.respondedAt;
    if (responded != null &&
        (invite.status == 'ACCEPTED' ||
            invite.status == 'DECLINED' ||
            invite.status == 'REVOKED')) {
      return '$sent  •  ${_formatDate(responded)}';
    }
    return sent;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool canRevoke = invite.status == 'PENDING';
    final bool canResend =
        invite.status == 'PENDING' || invite.status == 'EXPIRED';
    final initial = invite.email.isEmpty ? '?' : invite.email[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, 3),
            blurRadius: 8,
            color: Color(0x1F000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withValues(alpha: 0.2),
                ),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    if (invite.invitedByName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Invited by ${invite.invitedByName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: invite.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _dateLine(),
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
          if (canResend) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: disabled ? null : onResend,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.primary,
                        side: BorderSide(color: cs.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: resendLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: cs.primary,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Resend'),
                    ),
                  ),
                ),
                if (canRevoke) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: FilledButton(
                        onPressed: disabled ? null : onRevoke,
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: revokeLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: cs.onPrimary,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Revoke'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final app = context.appColors;

    late final Color foreground;
    late final String label;

    switch (status) {
      case 'ACCEPTED':
        foreground = app.success;
        label = 'Accepted';
        break;
      case 'DECLINED':
        foreground = cs.error;
        label = 'Declined';
        break;
      case 'REVOKED':
        foreground = cs.onSurfaceVariant;
        label = 'Revoked';
        break;
      case 'EXPIRED':
        foreground = app.mutedText;
        label = 'Expired';
        break;
      default:
        foreground = app.warning;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
