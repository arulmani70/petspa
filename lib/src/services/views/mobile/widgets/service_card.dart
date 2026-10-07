import 'package:flutter/material.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';

class ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final VoidCallback? onTap;
  final bool selected;

  const ServiceCard({
    super.key,
    required this.service,
    this.onTap,
    this.selected = false,
  });

  String get _name => service[Constants.database.COLUMN_SERVICE_NAME]?.toString() ?? '';

  String get _description => service[Constants.database.COLUMN_DESCRIPTION]?.toString() ?? '';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF000000) : const Color(0xFFE4E9EC),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.04 * 255).round()),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.pets, color: Color(0xFF000000), size: 32),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF000000),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF7B8794),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        "View Service",
                        style: TextStyle(
                          fontFamily: 'Parkinsans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF000000),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF000000)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
