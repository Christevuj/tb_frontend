import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../accounts/medical_staff_create.dart';
import './admin_login.dart' show AdminLogin;
import './email_config.dart'; // Import email configuration
import './email_credentials_page.dart'; // Import email credentials management

/*
 * EMAIL CONFIGURATION REQUIRED:
 * 
 * To enable actual email sending, you need to:
 * 1. Replace 'your-admin-email@gmail.com' with your actual admin Gmail address
 * 2. Replace 'your-app-password' with your Gmail App Password
 * 
 * To create a Gmail App Password:
 * 1. Go to your Google Account settings
 * 2. Select Security > 2-Step Verification
 * 3. Select App passwords
 * 4. Generate a new app password for this app
 * 5. Use the generated password in the SMTP configuration below
 * 
 * Note: The current implementation will show an error until properly configured.
 */

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.grey,
        primaryColor: Colors.white,
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const AdminDashboard(),
    );
  }
}

enum DashboardTab {
  dashboard,
  doctors,
  patients,
  healthWorkers,
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _isHovered = false;
  DashboardTab _selectedTab = DashboardTab.dashboard;

  @override
  void initState() {
    super.initState();
    // Check SMTP credentials when dashboard loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSmtpCredentials();
    });
  }

  // Check if SMTP credentials are configured
  Future<void> _checkSmtpCredentials() async {
    try {
      final emailConfig = await EmailConfig.getCurrentAdminEmailConfig();

      if (emailConfig == null ||
          emailConfig['email']?.isEmpty == true ||
          emailConfig['password']?.isEmpty == true) {
        if (mounted) {
          _showSmtpCredentialsDialog();
        }
      }
    } catch (e) {
      print('Error checking SMTP credentials: $e');
      // If there's an error, assume credentials are not set and show dialog
      if (mounted) {
        _showSmtpCredentialsDialog();
      }
    }
  }

  // Show dialog prompting admin to set SMTP credentials
  void _showSmtpCredentialsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;

              return Container(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? constraints.maxWidth * 0.9 : 500,
                ),
                margin: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: isMobile ? 32 : 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.all(isMobile ? 20 : 24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.email_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Email Setup Required',
                                  style: GoogleFonts.poppins(
                                    fontSize: isMobile ? 18 : 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Configure SMTP credentials',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Padding(
                      padding: EdgeInsets.all(isMobile ? 20 : 24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              border: Border.all(color: Colors.orange.shade200),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.orange.shade600,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'To send accounts through email to doctors and healthworkers, you need to configure your SMTP email credentials in Email Settings first.',
                                    style: GoogleFonts.poppins(
                                      fontSize: isMobile ? 13 : 14,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Buttons
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      vertical: isMobile ? 14 : 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Later',
                                    style: GoogleFonts.poppins(
                                      fontSize: isMobile ? 14 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const EmailCredentialsPage(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.settings_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  label: Text(
                                    'Email Settings',
                                    style: GoogleFonts.poppins(
                                      fontSize: isMobile ? 14 : 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      vertical: isMobile ? 14 : 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Helper function to send credentials email
  Future<void> _sendCredentialsEmailHelper(
      BuildContext context, Map<String, dynamic> data, String type) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Text('Checking email configuration...',
                    style: GoogleFonts.poppins()),
              ],
            ),
          );
        },
      );

      // Get user data
      String tempPassword = '';
      String email = data['email'] ?? '';
      String name = data['fullName'] ?? data['name'] ?? 'User';

      if (email.isEmpty) {
        Navigator.pop(context);
        throw Exception('Email address is required');
      }

      // Get current admin's email configuration
      final emailConfig = await EmailConfig.getCurrentAdminEmailConfig();
      if (emailConfig == null) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Email Configuration Required'),
            content: const Text(
                'No email configuration found for current admin. Please add email credentials to your admin profile in Firestore:\n\n'
                '• smtpEmailCredentials: Your email address (Gmail, UIC.edu.ph, Outlook, etc.)\n'
                '• smtpPasswordCredentials: Your encrypted email password\n'
                '• displayName: Your display name (optional)\n\n'
                'Use the Email Credentials page to set up your configuration securely.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final adminEmail = emailConfig['email']!;
      final adminPassword = emailConfig['password']!;
      final adminName = emailConfig['name']!;

      // Get provider-specific requirements
      final smtpConfig = EmailConfig.getSmtpConfig(adminEmail);
      final minPasswordLength = smtpConfig['minPasswordLength'] as int;
      final requiresAppPassword = smtpConfig['requiresAppPassword'] as bool;

      if (adminPassword.isEmpty || adminPassword.length < minPasswordLength) {
        Navigator.pop(context);

        final providerName = adminEmail.split('@').last;
        final passwordType = requiresAppPassword ? 'App Password' : 'password';

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invalid Email Configuration'),
            content: Text(
                'Email $passwordType is missing or invalid. Please update your admin profile with a valid $minPasswordLength-character $passwordType for $providerName.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Get temporary password from Firestore
      final docSnapshot = await FirebaseFirestore.instance
          .collection(type == 'doctor' ? 'doctors' : 'healthcare')
          .where('email', isEqualTo: email)
          .get();

      if (docSnapshot.docs.isNotEmpty) {
        final userData = docSnapshot.docs.first.data();
        tempPassword = userData['tempPassword'] ?? 'TBisita2024!';
      } else {
        tempPassword = 'TBisita2024!';
      }

      // Update loading dialog message
      Navigator.pop(context); // Close first dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.email_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sending Email...',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while we send the credentials',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );

      // Configure SMTP server using dynamic admin config
      final smtpServer = SmtpServer(
        emailConfig['smtpServer']!,
        port: int.parse(emailConfig['smtpPort']!),
        allowInsecure: EmailConfig.allowInsecure,
        ssl: EmailConfig.useSSL,
        username: adminEmail,
        password: adminPassword,
      );

      // Create and send email
      final message = Message()
        ..from = Address(adminEmail, adminName)
        ..recipients.add(email)
        ..subject = 'Your TBisita Account Credentials'
        ..html = EmailConfig.getEmailTemplate(name, email, tempPassword);

      await send(message, smtpServer);

      Navigator.pop(context); // Close loading dialog
      _showEmailSentConfirmation(context, email);
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      // Enhanced error handling for SMTP issues
      String errorMessage = 'Failed to send email: $e';
      String suggestion = '';

      if (e.toString().contains('BadCredentialsException') ||
          e.toString().contains('Authentication')) {
        errorMessage =
            'Email authentication failed. Please check your email credentials.';
      } else if (e.toString().contains('Network') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('SocketException')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('host lookup') ||
          e.toString().contains('No address associated with hostname') ||
          e.toString().contains('Unknown host')) {
        errorMessage =
            'SMTP server not found. The server address may be incorrect.';

        // Special handling for UIC.edu.ph
        if (e.toString().contains('uic.edu.ph') ||
            e.toString().contains('office365') ||
            e.toString().contains('smtp')) {
          suggestion = '\n\nFor UIC.edu.ph emails, try these SMTP servers:\n'
              '• smtp.office365.com:587 (if UIC uses Office 365)\n'
              '• smtp.gmail.com:587 (if UIC uses Google Workspace)\n'
              '• mail.uic.edu.ph:587 (direct UIC server)\n\n'
              'Contact UIC IT support to confirm the correct SMTP server.';
        }
      }

      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.error_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Email Error',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Failed to send credentials',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          errorMessage + suggestion,
                          style: GoogleFonts.robotoMono(
                            fontSize: 12,
                            color: Colors.red.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'OK',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _showEmailSentConfirmation(BuildContext context, String email) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Email Sent Successfully',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Credentials delivered',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          border: Border.all(color: Colors.green.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.email_rounded,
                              color: Colors.green.shade600,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Credentials have been sent successfully to $email',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'OK',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAccountCreationDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MedicalStaffCreatePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: isMobile ? _buildMobileAppBar() : null,
          drawer: isMobile ? _buildMobileDrawer() : null,
          body: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
        );
      },
    );
  }

  AppBar _buildMobileAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withOpacity(0.05),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'Admin Dashboard',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
              fontSize: 18,
            ),
          ),
        ],
      ),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF1F2937)),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F2937), Color(0xFF111827)],
          ),
        ),
        child: Column(
          children: [
            DrawerHeader(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Admin Panel',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildMobileMenuItem(
                      icon: Icons.dashboard_rounded,
                      label: "Dashboard",
                      tab: DashboardTab.dashboard),
                  _buildMobileMenuItem(
                      icon: Icons.medical_services_rounded,
                      label: "Doctors",
                      tab: DashboardTab.doctors),
                  _buildMobileMenuItem(
                      icon: Icons.people_rounded,
                      label: "Patients",
                      tab: DashboardTab.patients),
                  _buildMobileMenuItem(
                      icon: Icons.health_and_safety_rounded,
                      label: "Health Workers",
                      tab: DashboardTab.healthWorkers),
                  const Divider(color: Colors.white24, thickness: 1, height: 1),
                  _buildEmailSettingsMenuItem(),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showAccountCreationDialog,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_circle_rounded,
                            color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Create Account',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: InkWell(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (context) => const AdminLogin()),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 14.0, horizontal: 20.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Logout',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileMenuItem({
    required IconData icon,
    required String label,
    required DashboardTab tab,
  }) {
    final isSelected = _selectedTab == tab;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isSelected ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _selectedTab = tab);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailSettingsMenuItem() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            Navigator.pop(context); // Close drawer
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EmailCredentialsPage(),
              ),
            );
            if (result == true) {
              // Refresh UI if credentials were updated
              setState(() {});
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.email_outlined, color: Colors.white, size: 24),
                const SizedBox(width: 16),
                Text(
                  'Email Settings',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return _getSelectedTabContent();
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        _buildSidebar(),
        Expanded(child: _getSelectedTabContent()),
      ],
    );
  }

  Widget _buildSidebar() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: _isHovered ? 250 : 90,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F2937), Color(0xFF111827)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 40),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 50, end: _isHovered ? 60 : 50),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              builder: (context, size, child) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: size,
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    children: [
                      _buildSidebarButton(
                          icon: Icons.dashboard_rounded,
                          label: "Dashboard",
                          tab: DashboardTab.dashboard),
                      const SizedBox(height: 20),
                      _buildSidebarButton(
                          icon: Icons.medical_services_rounded,
                          label: "Doctors",
                          tab: DashboardTab.doctors),
                      const SizedBox(height: 20),
                      _buildSidebarButton(
                          icon: Icons.people_rounded,
                          label: "Patients",
                          tab: DashboardTab.patients),
                      const SizedBox(height: 20),
                      _buildSidebarButton(
                          icon: Icons.health_and_safety_rounded,
                          label: "Health Workers",
                          tab: DashboardTab.healthWorkers),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: InkWell(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (context) => const AdminLogin()),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: 14.0,
                    horizontal: _isHovered ? 20.0 : 14.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: _isHovered
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded,
                          color: Colors.white, size: 20),
                      if (_isHovered) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarButton({
    required IconData icon,
    required String label,
    required DashboardTab tab,
  }) {
    final isSelected = _selectedTab == tab;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isSelected ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFFEF4444).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedTab = tab),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: 14.0,
              horizontal: _isHovered ? 16.0 : 14.0,
            ),
            child: Row(
              mainAxisAlignment: _isHovered
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                if (_isHovered) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getSelectedTabContent() {
    switch (_selectedTab) {
      case DashboardTab.doctors:
        return DoctorsView(onSendEmail: _sendCredentialsEmailHelper);
      case DashboardTab.patients:
        return PatientsView(onSendEmail: _sendCredentialsEmailHelper);
      case DashboardTab.healthWorkers:
        return HealthWorkersView(
          onSendEmail: _sendCredentialsEmailHelper,
        );
      case DashboardTab.dashboard:
        return DashboardView(onNavigateToTab: (tab) {
          setState(() {
            _selectedTab = tab;
          });
        });
    }
  }
}

// Dashboard Overview
class DashboardView extends StatelessWidget {
  final Function(DashboardTab)? onNavigateToTab;

  const DashboardView({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: isMobile ? 28 : 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Dashboard Overview",
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 24 : 32,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1F2937),
                      letterSpacing: -1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Doctors Table
              _buildCompactTable(
                title: "Doctors",
                icon: Icons.medical_services_rounded,
                collection: "doctors",
                isMobile: isMobile,
                onNavigateToTab: onNavigateToTab,
              ),
              const SizedBox(height: 20),

              // Patients Table
              _buildCompactTable(
                title: "Patients",
                icon: Icons.people_rounded,
                collection: "users",
                isMobile: isMobile,
                onNavigateToTab: onNavigateToTab,
              ),
              const SizedBox(height: 20),

              // Health Workers Table
              _buildCompactTable(
                title: "Health Workers",
                icon: Icons.health_and_safety_rounded,
                collection: "healthcare",
                isMobile: isMobile,
                onNavigateToTab: onNavigateToTab,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactTable({
    required String title,
    required IconData icon,
    required String collection,
    required bool isMobile,
    Function(DashboardTab)? onNavigateToTab,
  }) {
    // Build query based on collection type
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection(collection);

    // Add filtering for patients
    if (collection == 'users') {
      query = query.where('role', isEqualTo: 'patient');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query
          .limit(50) // Limit for dashboard overview
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard(title, icon);
        }

        if (snapshot.hasError) {
          return _buildErrorCard(title, icon);
        }

        final docs = snapshot.data?.docs ?? [];

        // Limit to 5 items for compact view
        final limitedDocs = docs.take(5).toList();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$title (${docs.length})',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),

              // Table
              if (limitedDocs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      'No $title found',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6B7280),
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildTableContent(collection, limitedDocs, context),
                ),

              // Show more button if there are more items
              if (docs.length > 5)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to the appropriate tab
                        if (onNavigateToTab != null) {
                          if (collection == 'doctors') {
                            onNavigateToTab(DashboardTab.doctors);
                          } else if (collection == 'users') {
                            onNavigateToTab(DashboardTab.patients);
                          } else if (collection == 'healthcare') {
                            onNavigateToTab(DashboardTab.healthWorkers);
                          }
                        }
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(
                        'View all ${docs.length} $title',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableContent(
      String collection, List<DocumentSnapshot> docs, BuildContext context) {
    return DataTable(
      headingRowHeight: 45,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 50,
      headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
      columns: _getColumns(collection),
      rows: docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return DataRow(
          cells: _getCells(collection, data, context),
        );
      }).toList(),
    );
  }

  List<DataColumn> _getColumns(String collection) {
    if (collection == 'doctors') {
      return [
        DataColumn(
            label: Text('Name',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13))),
        DataColumn(
            label: Text('Specialization',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13))),
        DataColumn(
            label: Text('Email',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13))),
        DataColumn(
            label: Text('Actions',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13))),
      ];
    } else if (collection == 'users') {
      return [
        DataColumn(
            label: Text('Name',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13))),
        DataColumn(
            label: Text('Email',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13))),
        DataColumn(
            label: Text('Status',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13))),
        DataColumn(
            label: Text('Actions',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13))),
      ];
    } else {
      // healthcare
      return [
        DataColumn(
            label: Text('Name',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13))),
        DataColumn(
            label: Text('Position',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13))),
        DataColumn(
            label: Text('Email',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13))),
        DataColumn(
            label: Text('Actions',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13))),
      ];
    }
  }

  List<DataCell> _getCells(
      String collection, Map<String, dynamic> data, BuildContext context) {
    if (collection == 'doctors') {
      return [
        DataCell(Text(
          data['fullName'] ?? data['name'] ?? 'N/A',
          style: GoogleFonts.poppins(fontSize: 13),
        )),
        DataCell(Text(
          data['specialization'] ?? 'N/A',
          style: GoogleFonts.poppins(fontSize: 13),
        )),
        DataCell(Text(
          data['email'] ?? 'N/A',
          style: GoogleFonts.poppins(fontSize: 13),
        )),
        DataCell(
          IconButton(
            icon: const Icon(Icons.visibility_rounded,
                color: Color(0xFFEF4444), size: 20),
            onPressed: () => _showDetailsDialog(context, data, 'doctor'),
            tooltip: 'View Details',
          ),
        ),
      ];
    } else if (collection == 'users') {
      String name = '';
      if (data['firstName'] != null && data['lastName'] != null) {
        name = '${data['firstName']} ${data['lastName']}';
      } else if (data['name'] != null) {
        name = data['name'];
      } else {
        name = 'N/A';
      }

      final status = data['status'] ?? 'Pending';

      return [
        DataCell(Text(name, style: GoogleFonts.poppins(fontSize: 13))),
        DataCell(Text(data['email'] ?? 'N/A',
            style: GoogleFonts.poppins(fontSize: 13))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'Approved'
                  ? Colors.green.withOpacity(0.1)
                  : status == 'Rejected'
                      ? Colors.red.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: GoogleFonts.poppins(
                color: status == 'Approved'
                    ? Colors.green
                    : status == 'Rejected'
                        ? Colors.red
                        : Colors.orange,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ),
        DataCell(
          IconButton(
            icon: const Icon(Icons.visibility_rounded,
                color: Color(0xFFEF4444), size: 20),
            onPressed: () => _showDetailsDialog(context, data, 'patient'),
            tooltip: 'View Details',
          ),
        ),
      ];
    } else {
      // healthcare
      return [
        DataCell(Text(
          data['fullName'] ?? data['name'] ?? 'N/A',
          style: GoogleFonts.poppins(fontSize: 13),
        )),
        DataCell(Text(
          data['specialization'] ?? 'N/A',
          style: GoogleFonts.poppins(fontSize: 13),
        )),
        DataCell(Text(
          data['email'] ?? 'N/A',
          style: GoogleFonts.poppins(fontSize: 13),
        )),
        DataCell(
          IconButton(
            icon: const Icon(Icons.visibility_rounded,
                color: Color(0xFFEF4444), size: 20),
            onPressed: () => _showDetailsDialog(context, data, 'healthworker'),
            tooltip: 'View Details',
          ),
        ),
      ];
    }
  }

  void _showDetailsDialog(
      BuildContext context, Map<String, dynamic> data, String type) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        type == 'doctor'
                            ? Icons.medical_services_rounded
                            : type == 'patient'
                                ? Icons.person_rounded
                                : Icons.health_and_safety_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type == 'doctor'
                                ? 'Doctor Details'
                                : type == 'patient'
                                    ? 'Patient Details'
                                    : 'Health Worker Details',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            data['fullName'] ?? data['name'] ?? 'N/A',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildDetailsContent(data, type),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDetailsContent(Map<String, dynamic> data, String type) {
    List<Widget> widgets = [];

    if (type == 'doctor') {
      widgets.add(
          _buildDetailRow('Name', data['fullName'] ?? data['name'] ?? 'N/A'));
      widgets.add(_buildDetailRow('Email', data['email'] ?? 'N/A'));
      widgets.add(
          _buildDetailRow('Specialization', data['specialization'] ?? 'N/A'));

      if (data['affiliations'] != null && data['affiliations'] is List) {
        widgets.add(const SizedBox(height: 8));
        widgets.add(Text('Affiliations:',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)));
        for (var aff in (data['affiliations'] as List)) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child:
                Text('• ${aff['name'] ?? 'N/A'}', style: GoogleFonts.poppins()),
          ));
        }
      }
    } else if (type == 'patient') {
      String name = '';
      if (data['firstName'] != null && data['lastName'] != null) {
        name = '${data['firstName']} ${data['lastName']}';
      } else if (data['name'] != null) {
        name = data['name'];
      } else {
        name = 'N/A';
      }

      widgets.add(_buildDetailRow('Name', name));
      widgets.add(_buildDetailRow('Email', data['email'] ?? 'N/A'));
      widgets.add(_buildDetailRow('Status', data['status'] ?? 'Pending'));
    } else {
      // healthworker
      final facilityName = data['facility'] != null && data['facility'] is Map
          ? data['facility']['name'] ?? 'N/A'
          : 'N/A';

      widgets.add(
          _buildDetailRow('Name', data['fullName'] ?? data['name'] ?? 'N/A'));
      widgets.add(_buildDetailRow('Email', data['email'] ?? 'N/A'));
      widgets.add(_buildDetailRow('Position', data['specialization'] ?? 'N/A'));
      widgets.add(_buildDetailRow('Facility', facilityName));
    }

    return widgets;
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(String title, IconData icon) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String title, IconData icon) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'Error loading $title',
          style: GoogleFonts.poppins(color: Colors.red),
        ),
      ),
    );
  }
}

// Doctors View
class DoctorsView extends StatefulWidget {
  final Function(BuildContext, Map<String, dynamic>, String) onSendEmail;

  const DoctorsView({super.key, required this.onSendEmail});

  @override
  State<DoctorsView> createState() => _DoctorsViewState();
}

class _DoctorsViewState extends State<DoctorsView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Multi-select functionality
  Set<String> selectedDoctorIds = {};
  bool _isSelectionMode = false;

  // Cache for filtered results to avoid repeated filtering
  List<DocumentSnapshot>? _cachedDocs;
  String _lastSearchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DocumentSnapshot> _filterDoctors(List<DocumentSnapshot> docs) {
    // Use cached results if search query hasn't changed
    if (_lastSearchQuery == _searchQuery && _cachedDocs != null) {
      return _cachedDocs!;
    }

    List<DocumentSnapshot> filtered;
    if (_searchQuery.isEmpty) {
      filtered = docs;
    } else {
      filtered = docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;

        final name =
            (data['fullName'] ?? data['name'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        final specialization =
            (data['specialization'] ?? '').toString().toLowerCase();

        final query = _searchQuery.toLowerCase();

        return name.contains(query) ||
            email.contains(query) ||
            specialization.contains(query);
      }).toList();
    }

    // Cache the results
    _cachedDocs = filtered;
    _lastSearchQuery = _searchQuery;

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('doctors')
          .limit(100) // Limit to 100 documents at a time
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        final filteredDocs = _filterDoctors(allDocs);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 800;

            return Column(
              children: [
                // Header with Search
                Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Doctors (${filteredDocs.length})",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: isMobile ? 20 : 24,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText:
                                'Search doctors by name, email, or specialization...',
                            hintStyle: GoogleFonts.poppins(
                              color: const Color(0xFF6B7280),
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF6B7280),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      color: Color(0xFF6B7280),
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Table
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: _buildTable(filteredDocs, isMobile, context),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTable(
      List<DocumentSnapshot> docs, bool isMobile, BuildContext context) {
    if (docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'No doctors found',
            style: GoogleFonts.poppins(
              color: const Color(0xFF6B7280),
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
      ),
      child: Column(
        children: [
          // Selection toolbar when items are selected
          if (_isSelectionMode && selectedDoctorIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${selectedDoctorIds.length} selected',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _sendBulkEmail(docs),
                    icon: const Icon(Icons.email, size: 18),
                    label: const Text('Send Email'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          // DataTable
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
              columns: [
                DataColumn(
                  label: Text('Name',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                ),
                DataColumn(
                  label: Text('Specialization',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                ),
                DataColumn(
                  label: Text('Facility',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                ),
                DataColumn(
                  label: Text('Email',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                ),
                DataColumn(
                  label: Text('Actions',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                ),
              ],
              rows: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isSelected = selectedDoctorIds.contains(doc.id);

                // Get facility name
                String facilityName = 'N/A';
                if (data['affiliations'] != null &&
                    data['affiliations'] is List) {
                  final affiliations = data['affiliations'] as List;
                  if (affiliations.isNotEmpty && affiliations[0] is Map) {
                    facilityName = affiliations[0]['name'] ?? 'N/A';
                  }
                }

                return DataRow(
                  color: isSelected
                      ? WidgetStateProperty.all(Colors.grey.withOpacity(0.3))
                      : null,
                  onLongPress: () {
                    setState(() {
                      if (!_isSelectionMode) {
                        _isSelectionMode = true;
                        selectedDoctorIds.add(doc.id);
                      } else {
                        if (selectedDoctorIds.contains(doc.id)) {
                          selectedDoctorIds.remove(doc.id);
                          if (selectedDoctorIds.isEmpty) {
                            _isSelectionMode = false;
                          }
                        } else {
                          selectedDoctorIds.add(doc.id);
                        }
                      }
                    });
                  },
                  cells: [
                    DataCell(
                      Text(
                        data['fullName'] ?? data['name'] ?? 'N/A',
                        style: GoogleFonts.poppins(
                          color: isSelected ? Colors.grey.shade600 : null,
                        ),
                      ),
                      onTap: _isSelectionMode
                          ? () {
                              setState(() {
                                if (selectedDoctorIds.contains(doc.id)) {
                                  selectedDoctorIds.remove(doc.id);
                                  if (selectedDoctorIds.isEmpty) {
                                    _isSelectionMode = false;
                                  }
                                } else {
                                  selectedDoctorIds.add(doc.id);
                                }
                              });
                            }
                          : null,
                    ),
                    DataCell(
                      Text(
                        data['specialization'] ?? 'N/A',
                        style: GoogleFonts.poppins(
                          color: isSelected ? Colors.grey.shade600 : null,
                        ),
                      ),
                      onTap: _isSelectionMode
                          ? () {
                              setState(() {
                                if (selectedDoctorIds.contains(doc.id)) {
                                  selectedDoctorIds.remove(doc.id);
                                  if (selectedDoctorIds.isEmpty) {
                                    _isSelectionMode = false;
                                  }
                                } else {
                                  selectedDoctorIds.add(doc.id);
                                }
                              });
                            }
                          : null,
                    ),
                    DataCell(
                      Text(
                        facilityName,
                        style: GoogleFonts.poppins(
                          color: isSelected ? Colors.grey.shade600 : null,
                        ),
                      ),
                      onTap: _isSelectionMode
                          ? () {
                              setState(() {
                                if (selectedDoctorIds.contains(doc.id)) {
                                  selectedDoctorIds.remove(doc.id);
                                  if (selectedDoctorIds.isEmpty) {
                                    _isSelectionMode = false;
                                  }
                                } else {
                                  selectedDoctorIds.add(doc.id);
                                }
                              });
                            }
                          : null,
                    ),
                    DataCell(
                      Text(
                        data['email'] ?? 'N/A',
                        style: GoogleFonts.poppins(
                          color: isSelected ? Colors.grey.shade600 : null,
                        ),
                      ),
                      onTap: _isSelectionMode
                          ? () {
                              setState(() {
                                if (selectedDoctorIds.contains(doc.id)) {
                                  selectedDoctorIds.remove(doc.id);
                                  if (selectedDoctorIds.isEmpty) {
                                    _isSelectionMode = false;
                                  }
                                } else {
                                  selectedDoctorIds.add(doc.id);
                                }
                              });
                            }
                          : null,
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.visibility_rounded,
                                color: isSelected
                                    ? Colors.grey.shade400
                                    : const Color(0xFFEF4444)),
                            onPressed: () =>
                                _showDetailsDialog(context, data, 'doctor'),
                            tooltip: 'View Details',
                          ),
                          IconButton(
                            icon: Icon(Icons.email_rounded,
                                color: isSelected
                                    ? Colors.grey.shade400
                                    : const Color(0xFF059669)),
                            onPressed: () =>
                                widget.onSendEmail(context, data, 'doctor'),
                            tooltip: 'Send Credentials Email',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Multi-select helper methods for doctors
  void _clearSelection() {
    setState(() {
      selectedDoctorIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _sendBulkEmail(List<DocumentSnapshot> docs) async {
    final selectedDocs =
        docs.where((doc) => selectedDoctorIds.contains(doc.id)).toList();

    if (selectedDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No doctors selected')),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Email to Selected Doctors'),
        content: Text(
          'Are you sure you want to send credentials email to ${selectedDocs.length} selected doctor(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Send emails to all selected doctors
      for (final doc in selectedDocs) {
        final data = doc.data() as Map<String, dynamic>;
        await widget.onSendEmail(context, data, 'doctor');
      }

      // Clear selection after sending
      _clearSelection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Emails sent to ${selectedDocs.length} doctor(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showDetailsDialog(
      BuildContext context, Map<String, dynamic> data, String type) {
    final name = data['fullName'] ?? data['name'] ?? 'N/A';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.medical_services_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Doctor Details',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Name', name),
                      _buildDetailRow('Email', data['email'] ?? 'N/A'),
                      _buildDetailRow(
                          'Specialization', data['specialization'] ?? 'N/A'),
                      if (data['affiliations'] != null &&
                          data['affiliations'] is List) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFE5E7EB), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFEF4444),
                                      Color(0xFFDC2626)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Affiliations',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...((data['affiliations'] as List).map((aff) =>
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFEF4444),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            aff['name'] ?? 'N/A',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: const Color(0xFF374151),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Patients View
class PatientsView extends StatefulWidget {
  final Function(BuildContext, Map<String, dynamic>, String) onSendEmail;

  const PatientsView({super.key, required this.onSendEmail});

  @override
  State<PatientsView> createState() => _PatientsViewState();
}

class _PatientsViewState extends State<PatientsView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Multi-select state for patients
  bool _isSelectionMode = false;
  Set<String> selectedPatientIds = <String>{};

  // Cache for filtered results to avoid repeated filtering
  List<DocumentSnapshot>? _cachedDocs;
  String _lastSearchQuery = '';

  // Future for data loading
  Future<QuerySnapshot>? _patientsFuture;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  void _loadPatients() {
    print('Loading patients...'); // Debug
    setState(() {
      _patientsFuture = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'patient') // Filter for patients only
          .limit(100)
          .get()
          .timeout(const Duration(seconds: 10)); // Add timeout
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DocumentSnapshot> _filterPatients(List<DocumentSnapshot> docs) {
    print(
        'Filtering ${docs.length} documents with query: "$_searchQuery"'); // Debug

    try {
      // Use cached results if search query hasn't changed
      if (_lastSearchQuery == _searchQuery && _cachedDocs != null) {
        print('Using cached results: ${_cachedDocs!.length} docs'); // Debug
        return _cachedDocs!;
      }

      List<DocumentSnapshot> filtered;
      if (_searchQuery.isEmpty) {
        filtered = docs;
      } else {
        filtered = docs.where((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return false;

            final firstName =
                (data['firstName'] ?? '').toString().toLowerCase();
            final lastName = (data['lastName'] ?? '').toString().toLowerCase();
            final name = (data['name'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            final status = _getPatientStatus(data).toLowerCase();

            final fullName = '$firstName $lastName'.trim();
            final query = _searchQuery.toLowerCase();

            return firstName.contains(query) ||
                lastName.contains(query) ||
                name.contains(query) ||
                fullName.contains(query) ||
                email.contains(query) ||
                status.contains(query);
          } catch (e) {
            print('Error filtering document: $e'); // Debug
            return false;
          }
        }).toList();
      }

      // Cache the results
      _cachedDocs = filtered;
      _lastSearchQuery = _searchQuery;

      print('Filtered to ${filtered.length} documents'); // Debug
      return filtered;
    } catch (e) {
      print('Error in _filterPatients: $e'); // Debug
      return docs; // Return original docs if filtering fails
    }
  }

  String _getPatientStatus(Map<String, dynamic> data) {
    try {
      final status = data['status'] ?? 'Pending';
      final isApproved = data['isApproved'] ?? false;
      final consultationCompleted = data['consultationCompleted'] ?? false;
      final treatmentCompleted = data['treatmentCompleted'] ?? false;

      // Check for treatment completion first (highest priority)
      if (treatmentCompleted == true || status == 'Treatment Completed') {
        return 'Treatment Completed';
      }
      // Check for consultation completion
      else if (consultationCompleted == true ||
          status == 'Consultation Completed') {
        return 'Consultation Completed';
      }
      // Check for approval status
      else if (isApproved == true || status == 'Approved') {
        return 'Approved';
      }
      // Check for rejection
      else if (status == 'Rejected') {
        return 'Rejected';
      }
      // Default to pending
      else {
        return 'Pending';
      }
    } catch (e) {
      // Return default status if there's an error
      return 'Pending';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'treatment completed':
        return Colors.purple;
      case 'consultation completed':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  Color _getStatusBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'treatment completed':
        return Colors.purple.shade50;
      case 'consultation completed':
        return Colors.blue.shade50;
      case 'approved':
        return Colors.green.shade50;
      case 'rejected':
        return Colors.red.shade50;
      case 'pending':
      default:
        return Colors.orange.shade50;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: _patientsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allDocs = snapshot.data?.docs ?? [];
        print('Loaded ${allDocs.length} patient documents'); // Debug
        final filteredDocs = _filterPatients(allDocs);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 800;

            return Column(
              children: [
                // Header with Search
                Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Patients (${filteredDocs.length})",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: isMobile ? 20 : 24,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _loadPatients,
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Refresh',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            // Clear cache when search changes
                            _cachedDocs = null;
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText:
                                'Search patients by name, email, or status...',
                            hintStyle: GoogleFonts.poppins(
                              color: const Color(0xFF6B7280),
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF6B7280),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      color: Color(0xFF6B7280),
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Table
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: _buildTable(filteredDocs, isMobile),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTable(List<DocumentSnapshot> docs, bool isMobile) {
    if (docs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No patients found',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selection toolbar
          if (_isSelectionMode)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Text(
                    '${selectedPatientIds.length} patient(s) selected',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearSelection,
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _sendBulkEmail(docs),
                    icon: const Icon(Icons.email, size: 18),
                    label: const Text('Send Email'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          // DataTable
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
              columns: [
                DataColumn(
                    label: Text('Name',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w700))),
                DataColumn(
                    label: Text('Email',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w700))),
                DataColumn(
                    label: Text('Status',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w700))),
                DataColumn(
                    label: Text('Actions',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w700))),
              ],
              rows: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                String name = '';
                if (data['firstName'] != null && data['lastName'] != null) {
                  name = '${data['firstName']} ${data['lastName']}';
                } else if (data['name'] != null) {
                  name = data['name'];
                } else {
                  name = 'N/A';
                }

                // Get enhanced status using the helper method
                final displayStatus = _getPatientStatus(data);
                final statusColor = _getStatusColor(displayStatus);
                final backgroundColor =
                    _getStatusBackgroundColor(displayStatus);

                final isSelected = selectedPatientIds.contains(doc.id);

                return DataRow(
                  color: isSelected
                      ? WidgetStateProperty.all(Colors.grey.withOpacity(0.3))
                      : null,
                  onLongPress: () {
                    setState(() {
                      if (!_isSelectionMode) {
                        _isSelectionMode = true;
                        selectedPatientIds.add(doc.id);
                      } else {
                        if (selectedPatientIds.contains(doc.id)) {
                          selectedPatientIds.remove(doc.id);
                          if (selectedPatientIds.isEmpty) {
                            _isSelectionMode = false;
                          }
                        } else {
                          selectedPatientIds.add(doc.id);
                        }
                      }
                    });
                  },
                  cells: [
                    DataCell(
                      Text(name,
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.grey.shade600 : null,
                          )),
                      onTap: _isSelectionMode
                          ? () {
                              setState(() {
                                if (selectedPatientIds.contains(doc.id)) {
                                  selectedPatientIds.remove(doc.id);
                                  if (selectedPatientIds.isEmpty) {
                                    _isSelectionMode = false;
                                  }
                                } else {
                                  selectedPatientIds.add(doc.id);
                                }
                              });
                            }
                          : null,
                    ),
                    DataCell(
                      Text(data['email'] ?? 'N/A',
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.grey.shade600 : null,
                          )),
                      onTap: _isSelectionMode
                          ? () {
                              setState(() {
                                if (selectedPatientIds.contains(doc.id)) {
                                  selectedPatientIds.remove(doc.id);
                                  if (selectedPatientIds.isEmpty) {
                                    _isSelectionMode = false;
                                  }
                                } else {
                                  selectedPatientIds.add(doc.id);
                                }
                              });
                            }
                          : null,
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.grey.shade300
                              : backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          displayStatus,
                          style: GoogleFonts.poppins(
                            color:
                                isSelected ? Colors.grey.shade600 : statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Builder(
                        builder: (btnContext) => IconButton(
                          icon: Icon(Icons.visibility_rounded,
                              color: isSelected
                                  ? Colors.grey.shade400
                                  : const Color(0xFFEF4444)),
                          onPressed: () => _showDetailsDialog(btnContext, data),
                          tooltip: 'View Details',
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Multi-select helper methods for patients
  void _clearSelection() {
    setState(() {
      selectedPatientIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _sendBulkEmail(List<DocumentSnapshot> docs) async {
    final selectedDocs =
        docs.where((doc) => selectedPatientIds.contains(doc.id)).toList();

    if (selectedDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No patients selected')),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Email to Selected Patients'),
        content: Text(
          'Are you sure you want to send credentials email to ${selectedDocs.length} selected patient(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Send emails to all selected patients
      for (final doc in selectedDocs) {
        final data = doc.data() as Map<String, dynamic>;
        await widget.onSendEmail(context, data, 'patient');
      }

      // Clear selection after sending
      _clearSelection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Emails sent to ${selectedDocs.length} patient(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showDetailsDialog(BuildContext context, Map<String, dynamic> data) {
    String name = '';
    if (data['firstName'] != null && data['lastName'] != null) {
      name = '${data['firstName']} ${data['lastName']}';
    } else if (data['name'] != null) {
      name = data['name'];
    } else {
      name = 'N/A';
    }

    final displayStatus = _getPatientStatus(data);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient Details',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Name', name),
                      _buildDetailRow('Email', data['email'] ?? 'N/A'),
                      _buildDetailRow('Status', displayStatus),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Health Workers View
class HealthWorkersView extends StatefulWidget {
  final Function(BuildContext, Map<String, dynamic>, String) onSendEmail;

  const HealthWorkersView({super.key, required this.onSendEmail});

  @override
  State<HealthWorkersView> createState() => _HealthWorkersViewState();
}

class _HealthWorkersViewState extends State<HealthWorkersView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Multi-select state for health workers
  bool _isSelectionMode = false;
  Set<String> selectedHealthWorkerIds = <String>{};

  // Cache for filtered results to avoid repeated filtering
  List<DocumentSnapshot>? _cachedDocs;
  String _lastSearchQuery = '';

  // Future for data loading
  Future<QuerySnapshot>? _healthWorkersFuture;

  @override
  void initState() {
    super.initState();
    _loadHealthWorkers();
  }

  void _loadHealthWorkers() {
    print('Loading health workers...'); // Debug
    setState(() {
      _healthWorkersFuture = FirebaseFirestore.instance
          .collection('healthcare')
          .limit(100)
          .get()
          .timeout(const Duration(seconds: 10)); // Add timeout
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DocumentSnapshot> _filterHealthWorkers(List<DocumentSnapshot> docs) {
    // Use cached results if search query hasn't changed
    if (_lastSearchQuery == _searchQuery && _cachedDocs != null) {
      return _cachedDocs!;
    }

    List<DocumentSnapshot> filtered;
    if (_searchQuery.isEmpty) {
      filtered = docs;
    } else {
      filtered = docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;

        final name =
            (data['fullName'] ?? data['name'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        final specialization =
            (data['specialization'] ?? '').toString().toLowerCase();
        final facilityName = data['facility'] != null && data['facility'] is Map
            ? (data['facility']['name'] ?? '').toString().toLowerCase()
            : '';

        final query = _searchQuery.toLowerCase();

        return name.contains(query) ||
            email.contains(query) ||
            specialization.contains(query) ||
            facilityName.contains(query);
      }).toList();
    }

    // Cache the results
    _cachedDocs = filtered;
    _lastSearchQuery = _searchQuery;

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: _healthWorkersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allDocs = snapshot.data?.docs ?? [];
        final filteredDocs = _filterHealthWorkers(allDocs);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 800;

            return Column(
              children: [
                // Header with Search
                Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Health Workers (${filteredDocs.length})",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: isMobile ? 20 : 24,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText:
                                'Search health workers by name, email, position, or facility...',
                            hintStyle: GoogleFonts.poppins(
                              color: const Color(0xFF6B7280),
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF6B7280),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      color: Color(0xFF6B7280),
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Table
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: _buildTable(filteredDocs, isMobile, context),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTable(
      List<DocumentSnapshot> docs, bool isMobile, BuildContext context) {
    if (docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text('No health workers found',
              style: GoogleFonts.poppins(
                  color: const Color(0xFF6B7280), fontSize: 16)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selection toolbar
          if (_isSelectionMode)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Text(
                    '${selectedHealthWorkerIds.length} health worker(s) selected',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearSelection,
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _sendBulkEmail(docs),
                    icon: const Icon(Icons.email, size: 18),
                    label: const Text('Send Email'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          // DataTable
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
              columns: [
                DataColumn(
                    label: Text('Name',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w700))),
                DataColumn(
                    label: Text('Position',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w700))),
                DataColumn(
                    label: Text('Facility',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w700))),
                DataColumn(
                    label: Text('Email',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w700))),
                DataColumn(
                    label: Text('Actions',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w700))),
              ],
              rows: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;

                final facilityName =
                    data['facility'] != null && data['facility'] is Map
                        ? data['facility']['name'] ?? 'N/A'
                        : 'N/A';

                final isSelected = selectedHealthWorkerIds.contains(doc.id);

                return DataRow(
                  color: isSelected
                      ? WidgetStateProperty.all(Colors.grey.withOpacity(0.3))
                      : null,
                  onLongPress: () {
                    setState(() {
                      if (!_isSelectionMode) {
                        _isSelectionMode = true;
                        selectedHealthWorkerIds.add(doc.id);
                      } else {
                        if (selectedHealthWorkerIds.contains(doc.id)) {
                          selectedHealthWorkerIds.remove(doc.id);
                          if (selectedHealthWorkerIds.isEmpty) {
                            _isSelectionMode = false;
                          }
                        } else {
                          selectedHealthWorkerIds.add(doc.id);
                        }
                      }
                    });
                  },
                  cells: [
                    DataCell(
                      Text(data['fullName'] ?? data['name'] ?? 'N/A',
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.grey.shade600 : null,
                          )),
                      onTap: _isSelectionMode
                          ? () {
                              setState(() {
                                if (selectedHealthWorkerIds.contains(doc.id)) {
                                  selectedHealthWorkerIds.remove(doc.id);
                                  if (selectedHealthWorkerIds.isEmpty) {
                                    _isSelectionMode = false;
                                  }
                                } else {
                                  selectedHealthWorkerIds.add(doc.id);
                                }
                              });
                            }
                          : null,
                    ),
                    DataCell(
                      Text(data['specialization'] ?? 'N/A',
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.grey.shade600 : null,
                          )),
                      onTap: _isSelectionMode
                          ? () {
                              setState(() {
                                if (selectedHealthWorkerIds.contains(doc.id)) {
                                  selectedHealthWorkerIds.remove(doc.id);
                                  if (selectedHealthWorkerIds.isEmpty) {
                                    _isSelectionMode = false;
                                  }
                                } else {
                                  selectedHealthWorkerIds.add(doc.id);
                                }
                              });
                            }
                          : null,
                    ),
                    DataCell(
                      Text(facilityName,
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.grey.shade600 : null,
                          )),
                      onTap: _isSelectionMode
                          ? () {
                              setState(() {
                                if (selectedHealthWorkerIds.contains(doc.id)) {
                                  selectedHealthWorkerIds.remove(doc.id);
                                  if (selectedHealthWorkerIds.isEmpty) {
                                    _isSelectionMode = false;
                                  }
                                } else {
                                  selectedHealthWorkerIds.add(doc.id);
                                }
                              });
                            }
                          : null,
                    ),
                    DataCell(
                      Text(data['email'] ?? 'N/A',
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.grey.shade600 : null,
                          )),
                      onTap: _isSelectionMode
                          ? () {
                              setState(() {
                                if (selectedHealthWorkerIds.contains(doc.id)) {
                                  selectedHealthWorkerIds.remove(doc.id);
                                  if (selectedHealthWorkerIds.isEmpty) {
                                    _isSelectionMode = false;
                                  }
                                } else {
                                  selectedHealthWorkerIds.add(doc.id);
                                }
                              });
                            }
                          : null,
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.visibility_rounded,
                                color: isSelected
                                    ? Colors.grey.shade400
                                    : const Color(0xFFEF4444)),
                            onPressed: () => _showDetailsDialog(context, data),
                            tooltip: 'View Details',
                          ),
                          IconButton(
                            icon: Icon(Icons.email_rounded,
                                color: isSelected
                                    ? Colors.grey.shade400
                                    : const Color(0xFF059669)),
                            onPressed: () => widget.onSendEmail(
                                context, data, 'healthworker'),
                            tooltip: 'Send Credentials Email',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Multi-select helper methods for health workers
  void _clearSelection() {
    setState(() {
      selectedHealthWorkerIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _sendBulkEmail(List<DocumentSnapshot> docs) async {
    final selectedDocs =
        docs.where((doc) => selectedHealthWorkerIds.contains(doc.id)).toList();

    if (selectedDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No health workers selected')),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Email to Selected Health Workers'),
        content: Text(
          'Are you sure you want to send credentials email to ${selectedDocs.length} selected health worker(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Send emails to all selected health workers
      for (final doc in selectedDocs) {
        final data = doc.data() as Map<String, dynamic>;
        await widget.onSendEmail(context, data, 'healthworker');
      }

      // Clear selection after sending
      _clearSelection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Emails sent to ${selectedDocs.length} health worker(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showDetailsDialog(BuildContext context, Map<String, dynamic> data) {
    final facilityName = data['facility'] != null && data['facility'] is Map
        ? data['facility']['name'] ?? 'N/A'
        : 'N/A';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.health_and_safety_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Health Worker Details',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            data['fullName'] ?? data['name'] ?? 'N/A',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                          'Name', data['fullName'] ?? data['name'] ?? 'N/A'),
                      _buildDetailRow('Email', data['email'] ?? 'N/A'),
                      _buildDetailRow(
                          'Position', data['specialization'] ?? 'N/A'),
                      _buildDetailRow('Facility', facilityName),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
