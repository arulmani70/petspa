import 'package:flutter/material.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final step = index + 1;
        final isActive = step == currentStep;
        final isComplete = step < currentStep;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 18,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF0F766E)
                : isComplete
                    ? const Color(0xFF14B8A6)
                    : const Color(0xFFE4E9EC),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
