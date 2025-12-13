import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gradecalculator/services/connectivity_service.dart';
import 'package:gradecalculator/services/offline_queue_service.dart';

/// Widget to display connectivity status and pending sync operations
class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivityService, _) {
        if (connectivityService.isOnline) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade800,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                'Offline Mode',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '• Changes will sync when online',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact offline indicator for app bar
class CompactOfflineIndicator extends StatelessWidget {
  const CompactOfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivityService, _) {
        if (connectivityService.isOnline) {
          return const SizedBox.shrink();
        }

        final offlineQueue = OfflineQueueService();
        final pendingCount = offlineQueue.pendingCount;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade800,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(
                'Offline',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (pendingCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pendingCount.toString(),
                    style: GoogleFonts.poppins(
                      color: Colors.orange.shade800,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
