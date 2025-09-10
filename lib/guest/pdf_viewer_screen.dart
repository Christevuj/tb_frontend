// lib/guest/pdf_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfViewerScreen extends StatefulWidget {
  final String assetPath;
  const PdfViewerScreen({super.key, required this.assetPath});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfControllerPinch _pdfController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _totalPages = 0;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();

    _pdfController = PdfControllerPinch(
      document: PdfDocument.openAsset(widget.assetPath),
      initialPage: 1,
      viewportFraction: 0.95,
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int page, {bool animate = true}) async {
    if (page < 1 || (_totalPages != 0 && page > _totalPages)) return;

    if (animate) {
      await _pdfController.animateToPage(
        pageNumber: page,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _pdfController.jumpToPage(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeRed = const Color(0xE0F44336);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: Column(
        children: [
          // --- Custom Header ---
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
                    icon: Icon(Icons.arrow_back, color: themeRed),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Text(
                  "Manual Procedures",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: themeRed,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),

          // --- Search Bar (page-number search) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      hintText: "Enter page number (or type '1')",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (text) async {
                      final page = int.tryParse(text.trim());
                      if (page != null) {
                        await _goToPage(page, animate: true);
                        FocusScope.of(context).unfocus();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                "Text search not supported here. Try entering a page number."),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: () async {
                      final page = int.tryParse(_searchController.text.trim());
                      if (page != null) {
                        await _goToPage(page, animate: true);
                        FocusScope.of(context).unfocus();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text("Enter a valid page number to jump to."),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: Icon(Icons.arrow_forward, color: themeRed),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // --- PDF Viewer with vertical scrollbar ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    thickness: 8,
                    radius: const Radius.circular(10),
                    child: PdfViewPinch(
                      controller: _pdfController,
                      scrollDirection: Axis.vertical,
                      onDocumentLoaded: (doc) {
                        setState(() {
                          _totalPages = doc.pagesCount;
                        });
                      },
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // --- Page slider (bottom) ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Row(
              children: [
                Text(
                  "Page $_currentPage",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _currentPage.toDouble().clamp(
                        1.0, (_totalPages > 0 ? _totalPages.toDouble() : 1.0)),
                    min: 1,
                    max: (_totalPages > 0 ? _totalPages.toDouble() : 1.0),
                    divisions: (_totalPages > 0 ? _totalPages : 1),
                    label: _currentPage.toString(),
                    onChanged: (value) {
                      final page = value.round();
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    onChangeEnd: (value) {
                      _goToPage(value.round(), animate: false);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.last_page),
                  onPressed: () {
                    if (_totalPages > 0) _goToPage(_totalPages, animate: true);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
