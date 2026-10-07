import 'package:flutter/material.dart';
import 'package:shear_heaven_pet_spa/src/common/services/network_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

class NetworkStatusWidget extends StatefulWidget {
  final Widget child;

  const NetworkStatusWidget({super.key, required this.child});

  @override
  State<NetworkStatusWidget> createState() => _NetworkStatusWidgetState();
}

class _NetworkStatusWidgetState extends State<NetworkStatusWidget> {
  late final NetworkService _networkService;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _networkService = ServicesLocator.networkService;
    _isOnline = _networkService.isOnline;
    _networkService.networkStatusStream.listen((online) {
      if (mounted) {
        setState(() => _isOnline = online);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_isOnline)
          Container(
            width: double.infinity,
            color: Colors.orange,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  "You are offline. Changes will sync when you're back online.",
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
