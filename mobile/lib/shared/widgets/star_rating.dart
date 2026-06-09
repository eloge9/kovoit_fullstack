import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final int maxStars;
  final double size;
  final bool interactive;
  final void Function(int)? onRatingChanged;

  const StarRating({
    super.key,
    required this.rating,
    this.maxStars = 5,
    this.size = 20,
    this.interactive = false,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxStars, (i) {
        final starValue = i + 1;
        final isFilled = starValue <= rating;
        final isHalf = !isFilled && starValue - 0.5 <= rating;

        final icon = isFilled
            ? Icons.star
            : isHalf
                ? Icons.star_half
                : Icons.star_border;

        return GestureDetector(
          onTap: interactive ? () => onRatingChanged?.call(starValue) : null,
          child: Icon(
            icon,
            size: size,
            color: AppTheme.secondaryColor,
          ),
        );
      }),
    );
  }
}

class InteractiveStarRating extends StatefulWidget {
  final void Function(int) onRatingSelected;
  final int initialRating;

  const InteractiveStarRating({
    super.key,
    required this.onRatingSelected,
    this.initialRating = 0,
  });

  @override
  State<InteractiveStarRating> createState() => _InteractiveStarRatingState();
}

class _InteractiveStarRatingState extends State<InteractiveStarRating> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final star = i + 1;
        return GestureDetector(
          onTap: () {
            setState(() => _selected = star);
            widget.onRatingSelected(star);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              star <= _selected ? Icons.star : Icons.star_border,
              size: 40,
              color: AppTheme.secondaryColor,
            ),
          ),
        );
      }),
    );
  }
}
