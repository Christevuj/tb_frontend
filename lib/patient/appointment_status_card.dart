import 'package:flutter/material.dart';

class AppointmentStatusCard extends StatelessWidget {
  final String? status;
  const AppointmentStatusCard({Key? key, this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final s = status?.toLowerCase() ?? 'unknown';
    Color statusColor;
    String statusTitle;
    String statusDescription;
    IconData statusIcon;

    switch (s) {
      case 'pending':
        statusColor = Colors.amber.shade600;
        statusTitle = 'Waiting for Doctor';
        statusDescription = 'Your appointment is being reviewed';
        statusIcon = Icons.schedule;
        break;
      case 'approved':
        statusColor = Colors.green.shade600;
        statusTitle = 'Ready for Consultation';
        statusDescription = 'You can now join your video call';
        statusIcon = Icons.videocam;
        break;
      case 'consultation_finished':
        statusColor = Colors.blue.shade600;
        statusTitle = 'Consultation Completed';
        statusDescription = 'Your consultation is complete.';
        statusIcon = Icons.medical_services;
        break;
      case 'treatment_completed':
        statusColor = Colors.purple.shade600;
        statusTitle = 'Treatment Completed';
        statusDescription = 'All done! Your treatment is complete.';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red.shade600;
        statusTitle = 'Appointment Not Approved';
        statusDescription = 'Please book another appointment';
        statusIcon = Icons.info;
        break;
      default:
        statusColor = Colors.grey.shade600;
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
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              color: Colors.white,
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
                    color: Colors.grey.shade700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
