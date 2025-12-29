// Avatar widget for user display.

import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final String? imageUrl;

  const Avatar({
    super.key,
    required this.name,
    this.size = 48,
    this.imageUrl,
  });

  Color _getBackgroundColor() {
    // Generate consistent color from name
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFFEC4899), // Pink
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF10B981), // Emerald
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEF4444), // Red
      const Color(0xFF06B6D4), // Cyan
    ];

    final hash = name.codeUnits.fold(0, (prev, code) => prev + code);
    return colors[hash % colors.length];
  }

  String _getInitials() {
    final parts = name.split(RegExp(r'[@\s]'));
    if (parts.isEmpty) return '?';

    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts[0].length >= 2) {
      return parts[0].substring(0, 2).toUpperCase();
    } else {
      return parts[0].toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return ClipOval(
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(),
        ),
      );
    }

    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _getInitials(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
