import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../router/router.dart';
import '../../services/services.dart';

/// Shown after login when the user has profiles across multiple schools/roles.
/// Allows selecting the active session context.
class ProfilePickerScreen extends ConsumerWidget {
  const ProfilePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(userProfilesProvider);
    final client = ref.read(supabaseClientProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // Header
              Text('Select Profile', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'You have access to multiple accounts. Choose one to continue.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 32),

              // Profile list
              Expanded(
                child: profilesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.danger, size: 40),
                        const SizedBox(height: 12),
                        Text('Failed to load profiles', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.refresh(userProfilesProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (profiles) {
                    if (profiles.isEmpty) {
                      return _EmptyProfilesView(
                        onSignOut: () async {
                          await AuthService(client).signOut();
                        },
                      );
                    }
                    return ListView.separated(
                      itemCount: profiles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        return _ProfileCard(
                          profile: profile,
                          onTap: () async {
                            final session = ActiveSession(
                              schoolId: profile.schoolId,
                              schoolName: profile.school?.name ?? 'Unknown School',
                              profileId: profile.id,
                              role: profile.role,
                            );
                            await ref.read(activeSessionProvider.notifier).setActiveSession(session);
                            if (context.mounted) {
                              context.go(_dashboardForRole(profile.role));
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Sign out
              TextButton.icon(
                onPressed: () async {
                  await AuthService(client).signOut();
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dashboardForRole(String role) {
    switch (role) {
      case AppRoles.superAdmin:
        return AppRoutes.superAdminDashboard;
      case AppRoles.schoolAdmin:
        return AppRoutes.schoolAdminDashboard;
      case AppRoles.teacher:
        return AppRoutes.teacherDashboard;
      case AppRoles.parent:
        return AppRoutes.parentDashboard;
      case AppRoles.student:
        return AppRoutes.studentDashboard;
      default:
        return AppRoutes.profilePicker;
    }
  }
}

class _ProfileCard extends StatelessWidget {
  final ProfileModel profile;
  final VoidCallback onTap;

  const _ProfileCard({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(profile.role);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [roleColor.withAlpha(200), roleColor.withAlpha(100)],
                  ),
                ),
                child: Center(
                  child: Text(
                    profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Name & School
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.school?.name ?? 'Unknown School',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: roleColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: roleColor.withAlpha(80)),
                ),
                child: Text(
                  AppRoles.displayName(profile.role),
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case AppRoles.superAdmin:
        return const Color(0xFFF59E0B);
      case AppRoles.schoolAdmin:
        return const Color(0xFF6366F1);
      case AppRoles.teacher:
        return const Color(0xFF10B981);
      case AppRoles.parent:
        return const Color(0xFF3B82F6);
      case AppRoles.student:
        return const Color(0xFFEC4899);
      default:
        return AppTheme.textMuted;
    }
  }
}

class _EmptyProfilesView extends StatelessWidget {
  final VoidCallback onSignOut;
  const _EmptyProfilesView({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: const Icon(Icons.person_off_outlined, color: AppTheme.textMuted, size: 36),
          ),
          const SizedBox(height: 20),
          Text('No Profiles Found', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Contact your school administrator to be added to the system.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
