import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Certificate extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const Certificate({super.key, required this.appointment});

  @override
  State<Certificate> createState() => _CertificateState();
}

class _CertificateState extends State<Certificate> {
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _facilityNameController = TextEditingController();
  final TextEditingController _issuanceDayController = TextEditingController();
  final TextEditingController _issuanceMonthController =
      TextEditingController();
  final TextEditingController _issuanceYearController = TextEditingController();

  bool _isLoading = false;
  bool _hasExistingCertificate = false;
  Map<String, dynamic>? _doctorData;
  String? _doctorSignature;

  // Treatment type checkboxes
  bool _dsTreatment = false;
  bool _drTreatment = false;
  bool _preventiveTreatment = false;

  // Define theme color
  final Color _themeRed = const Color(0xFFF94F6D);

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
    _loadExistingCertificate();
    _initializeFields();
  }

  void _initializeFields() {
    // Pre-fill patient name from appointment
    _patientNameController.text = widget.appointment['patientName'] ?? '';

    // Pre-fill current date
    final now = DateTime.now();
    _issuanceDayController.text = now.day.toString();
    _issuanceMonthController.text = _getMonthName(now.month);
    _issuanceYearController.text = now.year.toString();
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month];
  }

  Future<void> _loadDoctorData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docSnapshot = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(user.uid)
          .get();

      if (docSnapshot.exists && mounted) {
        setState(() {
          _doctorData = docSnapshot.data();
        });

        // Pre-fill facility name
        if (_doctorData!['affiliations'] != null &&
            (_doctorData!['affiliations'] as List).isNotEmpty) {
          _facilityNameController.text =
              _doctorData!['affiliations'][0]['name'] ?? '';
        }
      }

      // Load doctor signature
      await _loadDoctorSignature();
    } catch (e) {
      debugPrint('Error loading doctor data: $e');
    }
  }

  Future<void> _loadDoctorSignature() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final signatureDoc = await FirebaseFirestore.instance
          .collection('doctor_signatures')
          .doc(user.uid)
          .get();

      if (signatureDoc.exists && mounted) {
        final data = signatureDoc.data()!;
        setState(() {
          if (data['signatureType'] == 'text') {
            _doctorSignature = 'text:${data['signatureText']}';
          } else if (data['signatureType'] == 'drawn') {
            _doctorSignature = data['signatureData'];
          } else {
            _doctorSignature = data['signatureUrl'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading doctor signature: $e');
    }
  }

  Future<void> _loadExistingCertificate() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('certificates')
          .where('appointmentId',
              isEqualTo: widget.appointment['appointmentId'])
          .get();

      if (snapshot.docs.isNotEmpty && mounted) {
        final certificateData = snapshot.docs.first.data();
        _patientNameController.text = certificateData['patientName'] ?? '';
        _facilityNameController.text = certificateData['facilityName'] ?? '';
        _issuanceDayController.text = certificateData['issuanceDay'] ?? '';
        _issuanceMonthController.text = certificateData['issuanceMonth'] ?? '';
        _issuanceYearController.text = certificateData['issuanceYear'] ?? '';

        setState(() {
          _dsTreatment = certificateData['dsTreatment'] ?? false;
          _drTreatment = certificateData['drTreatment'] ?? false;
          _preventiveTreatment =
              certificateData['preventiveTreatment'] ?? false;
          _hasExistingCertificate = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading existing certificate: $e');
    }
  }

  String _getDoctorName() {
    if (_doctorData == null) return 'Doctor Name';

    // Try different possible field combinations
    if (_doctorData!['fullName'] != null) {
      return 'Dr. ${_doctorData!['fullName']}';
    } else if (_doctorData!['firstName'] != null &&
        _doctorData!['lastName'] != null) {
      return 'Dr. ${_doctorData!['firstName']} ${_doctorData!['lastName']}';
    } else if (_doctorData!['firstName'] != null) {
      return 'Dr. ${_doctorData!['firstName']}';
    } else {
      return 'Dr. Doctor';
    }
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _facilityNameController.dispose();
    _issuanceDayController.dispose();
    _issuanceMonthController.dispose();
    _issuanceYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      bottomNavigationBar: null,
      extendBodyBehindAppBar: true,
      appBar: null,
      body: Column(
        children: [
          // Custom Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: _themeRed),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Text(
                  "TB Treatment Certificate",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _themeRed,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.redAccent, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const Center(
                      child: Text(
                        "Certification of Treatment Completion",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Certificate content
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          height: 1.6,
                        ),
                        children: [
                          const TextSpan(
                              text: "This is to certify that Mr./Ms. "),
                          WidgetSpan(
                            child: SizedBox(
                              width: 200,
                              child: TextField(
                                controller: _patientNameController,
                                decoration: const InputDecoration(
                                  border: UnderlineInputBorder(),
                                  isDense: true,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 4),
                                ),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const TextSpan(
                              text:
                                  ",\nbearer of his NTP Patient Booklet, has complied with the\nrequired treatment regimen.\n\n"),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Treatment type checkboxes
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          title: const Text("☐ DS - TB Treatment"),
                          value: _dsTreatment,
                          onChanged: (bool? value) {
                            setState(() {
                              _dsTreatment = value ?? false;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        CheckboxListTile(
                          title: const Text("☐ DR - TB Treatment"),
                          value: _drTreatment,
                          onChanged: (bool? value) {
                            setState(() {
                              _drTreatment = value ?? false;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        CheckboxListTile(
                          title: const Text("☐ TB Preventive Treatment"),
                          value: _preventiveTreatment,
                          onChanged: (bool? value) {
                            setState(() {
                              _preventiveTreatment = value ?? false;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Facility section
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          height: 1.6,
                        ),
                        children: [
                          const TextSpan(text: "at "),
                          WidgetSpan(
                            child: SizedBox(
                              width: 250,
                              child: TextField(
                                controller: _facilityNameController,
                                decoration: const InputDecoration(
                                  border: UnderlineInputBorder(),
                                  isDense: true,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 4),
                                ),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const TextSpan(
                              text:
                                  " DOTS Facility. S/he is no\nlonger infectious.\n\n"),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Issuance date section
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          height: 1.6,
                        ),
                        children: [
                          const TextSpan(text: "Issued this "),
                          WidgetSpan(
                            child: SizedBox(
                              width: 50,
                              child: TextField(
                                controller: _issuanceDayController,
                                decoration: const InputDecoration(
                                  border: UnderlineInputBorder(),
                                  isDense: true,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 4),
                                ),
                                style: const TextStyle(fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const TextSpan(text: "th day of "),
                          WidgetSpan(
                            child: SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _issuanceMonthController,
                                decoration: const InputDecoration(
                                  border: UnderlineInputBorder(),
                                  isDense: true,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 4),
                                ),
                                style: const TextStyle(fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const TextSpan(text: ", 20"),
                          WidgetSpan(
                            child: SizedBox(
                              width: 40,
                              child: TextField(
                                controller: _issuanceYearController,
                                decoration: const InputDecoration(
                                  border: UnderlineInputBorder(),
                                  isDense: true,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 4),
                                ),
                                style: const TextStyle(fontSize: 16),
                                textAlign: TextAlign.center,
                                maxLength: 2,
                                buildCounter: (context,
                                        {required currentLength,
                                        required isFocused,
                                        maxLength}) =>
                                    null,
                              ),
                            ),
                          ),
                          const TextSpan(text: "."),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Signature section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              height: 60,
                              width: 200,
                              decoration: const BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(color: Colors.black)),
                              ),
                              child: _doctorSignature != null
                                  ? (_doctorSignature!.startsWith('text:')
                                      ? Center(
                                          child: Text(
                                            _doctorSignature!.substring(5),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontStyle: FontStyle.italic,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        )
                                      : _doctorSignature!
                                              .startsWith('data:image')
                                          ? Image.memory(
                                              base64Decode(_doctorSignature!
                                                  .split(',')[1]),
                                              fit: BoxFit.contain,
                                            )
                                          : Image.network(
                                              _doctorSignature!,
                                              fit: BoxFit.contain,
                                            ))
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getDoctorName(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              "Physician",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                            const Text(
                              "(Signature over Printed Name)",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Preview button
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _themeRed),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isLoading ? null : _previewCertificate,
                      child: Text(
                        'Preview PDF',
                        style: TextStyle(color: _themeRed, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Save button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _themeRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isLoading ? null : _saveCertificate,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _hasExistingCertificate
                                  ? 'Update Certificate'
                                  : 'Save & Send Certificate',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _previewCertificate() async {
    if (!_validateFields()) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final pdfPath = await _generateCertificatePdf();
      if (pdfPath != null) {
        final file = File(pdfPath);
        if (await file.exists()) {
          await Printing.sharePdf(
            bytes: await file.readAsBytes(),
            filename: 'TB_Treatment_Certificate_Preview.pdf',
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error previewing certificate: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _validateFields() {
    if (_patientNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter patient name'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (!_dsTreatment && !_drTreatment && !_preventiveTreatment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one treatment type'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _saveCertificate() async {
    if (!_validateFields()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate PDF and upload to Cloudinary
      final certificateData = await _generateAndUploadCertificatePdf();

      if (certificateData == null) {
        throw Exception('Failed to generate or upload PDF');
      }

      final certificateInfo = {
        'appointmentId': widget.appointment['appointmentId'],
        'patientId': widget.appointment['patientId'],
        'doctorId': widget.appointment['doctorId'],
        'patientName': _patientNameController.text.trim(),
        'facilityName': _facilityNameController.text.trim(),
        'dsTreatment': _dsTreatment,
        'drTreatment': _drTreatment,
        'preventiveTreatment': _preventiveTreatment,
        'issuanceDay': _issuanceDayController.text.trim(),
        'issuanceMonth': _issuanceMonthController.text.trim(),
        'issuanceYear': _issuanceYearController.text.trim(),
        'pdfPath': certificateData['localPath'],
        'pdfUrl': certificateData['cloudinaryUrl'],
        'pdfPublicId': certificateData['publicId'],
        'doctorName': _getDoctorName(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_hasExistingCertificate) {
        // Update existing certificate
        final snapshot = await FirebaseFirestore.instance
            .collection('certificates')
            .where('appointmentId',
                isEqualTo: widget.appointment['appointmentId'])
            .get();

        if (snapshot.docs.isNotEmpty) {
          await snapshot.docs.first.reference.update(certificateInfo);
        }
      } else {
        // Create new certificate
        await FirebaseFirestore.instance
            .collection('certificates')
            .add(certificateInfo);
      }

      // Send notification to patient
      await FirebaseFirestore.instance.collection('patient_notifications').add({
        'patientUid':
            widget.appointment['patientUid'] ?? widget.appointment['patientId'],
        'appointmentId': widget.appointment['appointmentId'],
        'type': 'certificate_available',
        'title': 'Treatment Certificate Available',
        'message':
            'Your TB treatment completion certificate is ready for download.',
        'pdfPath': certificateData['localPath'],
        'pdfUrl': certificateData['cloudinaryUrl'],
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'doctorName': _getDoctorName(),
      });

      // Update the appointment to mark certificate as sent
      try {
        final appointmentQuery = await FirebaseFirestore.instance
            .collection('completed_appointments')
            .where('appointmentId',
                isEqualTo: widget.appointment['appointmentId'])
            .get();

        if (appointmentQuery.docs.isNotEmpty) {
          await appointmentQuery.docs.first.reference.update({
            'certificateSent': true,
            'certificateSentAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('Error updating appointment certificate status: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_hasExistingCertificate
                ? 'Certificate updated and sent to patient successfully!'
                : 'Certificate created and sent to patient successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving certificate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, String>?> _generateAndUploadCertificatePdf() async {
    try {
      // First generate the PDF locally
      final localPdfPath = await _generateCertificatePdf();
      if (localPdfPath == null) return null;

      // Read the PDF file for Cloudinary upload
      final file = File(localPdfPath);
      final bytes = await file.readAsBytes();

      // Create form data for Cloudinary upload
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final publicId =
          'certificates/certificate_${widget.appointment['appointmentId']}_$timestamp';

      // Prepare Cloudinary upload (you'll need to add your Cloudinary credentials)
      final cloudinaryUrl = await _uploadToCloudinary(bytes, publicId);

      if (cloudinaryUrl != null) {
        return {
          'localPath': localPdfPath,
          'cloudinaryUrl': cloudinaryUrl,
          'publicId': publicId,
        };
      }

      // Fallback to local path only if upload fails
      return {
        'localPath': localPdfPath,
        'cloudinaryUrl': '',
        'publicId': '',
      };
    } catch (e) {
      print('Error generating/uploading certificate PDF: $e');
      return null;
    }
  }

  Future<String?> _uploadToCloudinary(List<int> bytes, String publicId) async {
    try {
      // Replace these with your actual Cloudinary credentials
      const cloudName = 'YOUR_CLOUD_NAME';
      const apiKey = 'YOUR_API_KEY';
      const apiSecret = 'YOUR_API_SECRET';

      final url = 'https://api.cloudinary.com/v1_1/$cloudName/raw/upload';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      // Generate signature
      final signature =
          _generateCloudinarySignature(publicId, timestamp, apiSecret);

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['api_key'] = apiKey;
      request.fields['timestamp'] = timestamp;
      request.fields['public_id'] = publicId;
      request.fields['signature'] = signature;
      request.fields['resource_type'] = 'raw';

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: '$publicId.pdf',
      ));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseData);
        return jsonResponse['secure_url'];
      } else {
        print('Cloudinary upload failed: $responseData');
        return null;
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  String _generateCloudinarySignature(
      String publicId, String timestamp, String apiSecret) {
    final paramsToSign =
        'public_id=$publicId&timestamp=$timestamp&resource_type=raw';
    return 'sig_${paramsToSign.hashCode.abs()}';
  }

  Future<String?> _generateCertificatePdf() async {
    try {
      final pdf = pw.Document();

      // Get treatment types as a formatted string - using proper PDF rendering
      List<pw.Widget> treatmentTypeWidgets = [];

      // DS Treatment
      treatmentTypeWidgets.add(
        pw.Row(
          children: [
            pw.Container(
              width: 12,
              height: 12,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 1),
              ),
              child: _dsTreatment
                  ? pw.Center(
                      child: pw.Text('✓',
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    )
                  : null,
            ),
            pw.SizedBox(width: 8),
            pw.Text('DS - TB Treatment',
                style: const pw.TextStyle(fontSize: 16)),
          ],
        ),
      );

      // DR Treatment
      treatmentTypeWidgets.add(
        pw.Row(
          children: [
            pw.Container(
              width: 12,
              height: 12,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 1),
              ),
              child: _drTreatment
                  ? pw.Center(
                      child: pw.Text('✓',
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    )
                  : null,
            ),
            pw.SizedBox(width: 8),
            pw.Text('DR - TB Treatment',
                style: const pw.TextStyle(fontSize: 16)),
          ],
        ),
      );

      // TB Preventive Treatment
      treatmentTypeWidgets.add(
        pw.Row(
          children: [
            pw.Container(
              width: 12,
              height: 12,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 1),
              ),
              child: _preventiveTreatment
                  ? pw.Center(
                      child: pw.Text('✓',
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    )
                  : null,
            ),
            pw.SizedBox(width: 8),
            pw.Text('TB Preventive Treatment',
                style: const pw.TextStyle(fontSize: 16)),
          ],
        ),
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Text(
                    'Certification of Treatment Completion',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),

                pw.SizedBox(height: 40),

                // Main content
                pw.RichText(
                  text: pw.TextSpan(
                    style: const pw.TextStyle(fontSize: 16, height: 1.8),
                    children: [
                      const pw.TextSpan(
                          text: 'This is to certify that Mr./Ms. '),
                      pw.TextSpan(
                        text: _patientNameController.text.trim(),
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            decoration: pw.TextDecoration.underline),
                      ),
                      const pw.TextSpan(
                          text:
                              ', bearer of his NTP Patient Booklet, has complied with the required treatment regimen.\n\n'),
                    ],
                  ),
                ),

                // Treatment types with proper checkboxes
                pw.SizedBox(height: 20),
                ...treatmentTypeWidgets.map((widget) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 12),
                      child: widget,
                    )),

                pw.SizedBox(height: 20),

                // Facility information
                pw.RichText(
                  text: pw.TextSpan(
                    style: const pw.TextStyle(fontSize: 16, height: 1.8),
                    children: [
                      const pw.TextSpan(text: 'at '),
                      pw.TextSpan(
                        text: _facilityNameController.text.trim(),
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            decoration: pw.TextDecoration.underline),
                      ),
                      const pw.TextSpan(
                          text:
                              ' DOTS Facility. S/he is no longer infectious.\n\n'),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Issuance date
                pw.RichText(
                  text: pw.TextSpan(
                    style: const pw.TextStyle(fontSize: 16, height: 1.8),
                    children: [
                      const pw.TextSpan(text: 'Issued this '),
                      pw.TextSpan(
                        text: _issuanceDayController.text.trim(),
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            decoration: pw.TextDecoration.underline),
                      ),
                      const pw.TextSpan(text: 'th day of '),
                      pw.TextSpan(
                        text: _issuanceMonthController.text.trim(),
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            decoration: pw.TextDecoration.underline),
                      ),
                      const pw.TextSpan(text: ', 20'),
                      pw.TextSpan(
                        text: _issuanceYearController.text.trim(),
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            decoration: pw.TextDecoration.underline),
                      ),
                      const pw.TextSpan(text: '.'),
                    ],
                  ),
                ),

                pw.Spacer(),

                // Signature section
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 200,
                          height: 60,
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide(width: 1)),
                          ),
                          child: _doctorSignature != null &&
                                  _doctorSignature!.startsWith('text:')
                              ? pw.Center(
                                  child: pw.Text(
                                    _doctorSignature!.substring(5),
                                    style: pw.TextStyle(
                                      fontSize: 18,
                                      fontStyle: pw.FontStyle.italic,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                )
                              : pw.Container(),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          _getDoctorName(),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Physician',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.normal,
                          ),
                        ),
                        pw.Text(
                          '(Signature over Printed Name)',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // Save PDF to device storage
      final directory = await getApplicationDocumentsDirectory();
      final patientName = _patientNameController.text.replaceAll(' ', '_');
      final fileName =
          'TB_Certificate_${patientName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      return file.path;
    } catch (e) {
      debugPrint('Error generating certificate PDF: $e');
      return null;
    }
  }
}
