import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../models/allergen.dart';
import '../../models/family_member.dart';
import '../auth/account_access_screen.dart';
import '../../widgets/allergen_selector.dart';
import '../../widgets/member_avatar.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({
    super.key,
    required this.session,
    required this.auth,
  });

  final AppSession session;
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 110),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your family',
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 6),
                        Text(
                          'One scan checks everyone selected.',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.inkSoft,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => _showMemberEditor(context),
                      icon: const Icon(Icons.person_add_alt_1_rounded,
                          color: AppColors.acid),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...session.family.map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _FamilyMemberCard(
                    member: member,
                    onTap: () => _showMemberEditor(context, member: member),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _showMemberEditor(context),
                icon: const Icon(Icons.add_rounded, color: AppColors.green),
                label: const Text('Add family member'),
              ),
              const SizedBox(height: 24),
              _AccountCard(auth: auth),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  gradient: AppGradients.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: AppColors.greenDark),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Use nicknames for children if preferred. SafeBite does not need dates of birth or medical records.',
                        style:
                            TextStyle(color: AppColors.greenDark, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showMemberEditor(BuildContext context, {FamilyMember? member}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.canvas,
      builder: (_) => _MemberEditor(session: session, member: member),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final signedIn = auth.isSignedIn;
        return Card(
          color: AppColors.greenDark,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.acid,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    signedIn
                        ? Icons.cloud_done_rounded
                        : Icons.person_outline_rounded,
                    color: AppColors.greenDark,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        signedIn ? 'Account connected' : 'Guest mode',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        signedIn
                            ? auth.user?.email ?? 'Signed in securely'
                            : 'Sign in to prepare for profile syncing.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.66),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: signedIn
                      ? auth.signOut
                      : () => _openAccountAccess(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.acid,
                  ),
                  child: Text(signedIn ? 'Sign out' : 'Sign in'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAccountAccess(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (routeContext) => AccountAccessScreen(
          auth: auth,
          allowGuest: false,
          onComplete: () async {
            if (routeContext.mounted) Navigator.pop(routeContext);
          },
        ),
      ),
    );
  }
}

class _FamilyMemberCard extends StatelessWidget {
  const _FamilyMemberCard({required this.member, required this.onTap});

  final FamilyMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFF4FFF7)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                MemberAvatar(member: member, size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(member.name,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(width: 8),
                          Text(member.relationship,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                      const SizedBox(height: 7),
                      if (member.allergenIds.isEmpty)
                        const Text('No preferences selected',
                            style: TextStyle(color: AppColors.inkSoft))
                      else
                        Text(
                          member.allergenIds
                              .map((id) => Allergens.byId(id).label)
                              .join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.edit_outlined,
                    color: AppColors.inkSoft, size: 21),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberEditor extends StatefulWidget {
  const _MemberEditor({required this.session, this.member});

  final AppSession session;
  final FamilyMember? member;

  @override
  State<_MemberEditor> createState() => _MemberEditorState();
}

class _MemberEditorState extends State<_MemberEditor> {
  static const _relationships = ['You', 'Partner', 'Child', 'Parent', 'Other'];
  late final TextEditingController _nameController;
  late String _relationship;
  late Set<String> _allergens;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member?.name ?? '');
    _relationship = widget.member?.relationship ?? 'Partner';
    _allergens = Set<String>.from(widget.member?.allergenIds ?? {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        16,
        22,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.member == null ? 'Add family member' : 'Edit profile',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name or nickname'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _relationship,
              decoration: const InputDecoration(labelText: 'Relationship'),
              items: _relationships
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _relationship = value ?? 'Other'),
            ),
            const SizedBox(height: 22),
            Text('Allergies and intolerances',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            AllergenSelector(
              selectedIds: _allergens,
              onChanged: (value) => setState(() => _allergens = value),
              compact: true,
            ),
            const SizedBox(height: 26),
            FilledButton(
              onPressed:
                  _nameController.text.trim().isEmpty || _saving ? null : _save,
              child: Text(
                  widget.member == null ? 'Add to family' : 'Save changes'),
            ),
            if (widget.member != null && widget.session.family.length > 1) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: _saving ? null : _remove,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Center(child: Text('Remove profile')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final existing = widget.member;
    final member = FamilyMember(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      relationship: _relationship,
      allergenIds: _allergens,
      avatarIndex: existing?.avatarIndex ?? widget.session.family.length,
    );
    if (existing == null) {
      await widget.session.addFamilyMember(member);
    } else {
      await widget.session.updateFamilyMember(member);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _remove() async {
    setState(() => _saving = true);
    await widget.session.removeFamilyMember(widget.member!.id);
    if (mounted) Navigator.pop(context);
  }
}
