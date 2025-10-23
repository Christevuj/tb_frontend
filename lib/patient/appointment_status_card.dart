import 'package:flutter/material.dart';

class AppointmentStatusCard extends StatelessWidget {
  final String? status;
  final VoidCallback? onCancel;
  const AppointmentStatusCard({Key? key, this.status, this.onCancel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
  final s = status?.toLowerCase() ?? 'unknown';
  Color statusColor = Colors.grey.shade700;
    String statusTitle;
    String statusDescription;
    IconData statusIcon;

    // Use neutral greys for all statuses to avoid colorful containers
    switch (s) {
      case 'pending':
        statusColor = Colors.grey.shade700;
        statusTitle = 'Waiting for Doctor';
        statusDescription = 'Your appointment is being reviewed';
        statusIcon = Icons.schedule;
        break;
      case 'approved':
        statusColor = Colors.grey.shade700;
        statusTitle = 'Ready for Consultation';
        statusDescription = 'You can now join your video call';
        statusIcon = Icons.videocam;
        break;
      case 'consultation_finished':
        statusColor = Colors.grey.shade700;
        statusTitle = 'Consultation Completed';
        statusDescription = 'Your consultation is complete.';
        statusIcon = Icons.medical_services;
        break;
      case 'treatment_completed':
        statusColor = Colors.grey.shade700;
        statusTitle = 'Treatment Completed';
        statusDescription = 'All done! Your treatment is complete.';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.grey.shade700;
        statusTitle = 'Appointment Not Approved';
        statusDescription = 'Please book another appointment';
        statusIcon = Icons.info;
        break;
      case 'incomplete_consultation':
        // Keep incomplete consultation neutral in the appointment status card (timeline consistency)
        statusColor = Colors.grey.shade700;
        statusTitle = 'Incomplete consultation';
        statusDescription = 'Consultation marked incomplete by the doctor.';
        statusIcon = Icons.report_problem_rounded;
        break;
      default:
        statusColor = Colors.grey.shade700;
        statusTitle = 'Status Unknown';
        statusDescription = 'Please check back later';
        statusIcon = Icons.help_outline;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  statusDescription,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // Show Cancel button for pending/waiting status if a handler is provided
          if ((status ?? '').toLowerCase() == 'pending' && onCancel != null)
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.redAccent.shade700),
              ),
            ),
        ],
      ),
    );
  }
}
