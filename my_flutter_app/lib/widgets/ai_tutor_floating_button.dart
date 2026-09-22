import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/student/ai_tutor_screen.dart';

/// A floating action button for quick access to the DeepSeek AI Tutor.
class AiTutorFloatingButton extends StatefulWidget {
  final bool mini;
  const AiTutorFloatingButton({super.key, this.mini = false});

  @override
  State<AiTutorFloatingButton> createState() => _AiTutorFloatingButtonState();
}

class _AiTutorFloatingButtonState extends State<AiTutorFloatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openAiTutor() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AiTutorScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mini) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: FloatingActionButton(
          heroTag: null,
          onPressed: _openAiTutor,
          backgroundColor: const Color(0xFF6557F5),
          foregroundColor: Colors.white,
          elevation: 6,
          tooltip: 'Ask AI Tutor',
          child: const Icon(Icons.auto_awesome_rounded, size: 24),
        ),
      );
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        elevation: 8,
        shadowColor: const Color(0xFF6557F5).withAlpha(120),
        child: InkWell(
          onTap: _openAiTutor,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6557F5),
                  Color(0xFF8B5CF6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6557F5).withAlpha(90),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Ask AI Tutor',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'DeepSeek',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
