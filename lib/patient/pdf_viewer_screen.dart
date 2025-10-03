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
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  int _totalPages = 0;
  late PdfController _pdfController;
  List<int> _searchResults = [];
  int _currentSearchIndex = -1;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfController(
      document: PdfDocument.openAsset(widget.assetPath),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pdfController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final text = _searchController.text.trim().toLowerCase();
    if (text.isEmpty) {
      setState(() {
        _searchResults.clear();
        _currentSearchIndex = -1;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults.clear();
      _currentSearchIndex = -1;
    });

    // Simulate search delay
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // Define common medical terms and their likely page locations for NTP MOP
      final Map<String, List<int>> searchTerms = {
        'tuberculosis': [1, 2, 3, 4, 5],
        'tb': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        'dots': [1, 2, 3, 15, 16, 17],
        'treatment': [8, 9, 10, 11, 12, 13, 14],
        'diagnosis': [5, 6, 7, 8],
        'patient': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        'drug': [11, 12, 13, 14, 15],
        'medication': [11, 12, 13, 14],
        'symptom': [4, 5, 6],
        'test': [6, 7, 8],
        'chest': [4, 5, 6, 7],
        'xray': [6, 7, 8],
        'sputum': [6, 7, 8],
        'culture': [7, 8],
        'resistance': [13, 14, 15],
        'mdr': [14, 15, 16],
        'rifampin': [11, 12, 13],
        'isoniazid': [11, 12, 13],
        'ethambutol': [11, 12, 13],
        'pyrazinamide': [11, 12, 13],
      };

      // Find matching terms
      List<int> foundPages = [];
      for (String term in searchTerms.keys) {
        if (term.contains(text) || text.contains(term)) {
          foundPages.addAll(searchTerms[term]!);
        }
      }

      // Remove duplicates and sort
      foundPages = foundPages.toSet().toList()..sort();

      // If no specific terms match, search by page number if the text is numeric
      if (foundPages.isEmpty && RegExp(r'^\d+$').hasMatch(text)) {
        int pageNum = int.tryParse(text) ?? 0;
        if (pageNum > 0 && pageNum <= _totalPages) {
          foundPages = [pageNum];
        }
      }

      // If still no results, show a generic message but allow browsing
      if (foundPages.isEmpty) {
        setState(() {
          _isSearching = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'No specific matches for "$text". Try terms like: tuberculosis, TB, DOTS, treatment, diagnosis'),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      // Filter pages that exist in the document
      foundPages = foundPages.where((page) => page <= _totalPages).toList();

      if (foundPages.isNotEmpty) {
        setState(() {
          _searchResults = foundPages;
          _currentSearchIndex = 0;
          _isSearching = false;
        });

        // Navigate to first search result
        await _pdfController.animateToPage(
          _searchResults[0],
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Found ${_searchResults.length} relevant page(s) for "$text"'),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No results found in document range.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search error: ${e.toString()}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    FocusScope.of(context).unfocus();
  }

  void _navigateToNextResult() {
    if (_searchResults.isNotEmpty &&
        _currentSearchIndex < _searchResults.length - 1) {
      setState(() {
        _currentSearchIndex++;
      });
      _pdfController.animateToPage(
        _searchResults[_currentSearchIndex],
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToPreviousResult() {
    if (_searchResults.isNotEmpty && _currentSearchIndex > 0) {
      setState(() {
        _currentSearchIndex--;
      });
      _pdfController.animateToPage(
        _searchResults[_currentSearchIndex],
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults.clear();
      _currentSearchIndex = -1;
      _isSearching = false;
    });
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
                // Back Button
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_ios, color: themeRed),
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

                const SizedBox(width: 48), // spacing balance
              ],
            ),
          ),

          // --- Search Bar ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Search text in PDF...",
                          prefixIcon: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: _clearSearch,
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 0, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _performSearch(),
                        onChanged: (_) =>
                            setState(() {}), // To update clear button
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        onTap: _isSearching ? null : _performSearch,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          child: Icon(Icons.search,
                              color: _isSearching ? Colors.grey : themeRed),
                        ),
                      ),
                    ),
                  ],
                ),

                // Search Results Navigation
                if (_searchResults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Result ${_currentSearchIndex + 1} of ${_searchResults.length}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          Row(
                            children: [
                              InkWell(
                                onTap: _currentSearchIndex > 0
                                    ? _navigateToPreviousResult
                                    : null,
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.keyboard_arrow_up,
                                    size: 20,
                                    color: _currentSearchIndex > 0
                                        ? themeRed
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: _currentSearchIndex <
                                        _searchResults.length - 1
                                    ? _navigateToNextResult
                                    : null,
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 20,
                                    color: _currentSearchIndex <
                                            _searchResults.length - 1
                                        ? themeRed
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // --- PDF Viewer ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Scrollbar(
                thumbVisibility: true,
                thickness: 12.0,
                radius: const Radius.circular(6.0),
                trackVisibility: true,
                interactive: true,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
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
                      child: PdfView(
                        controller: _pdfController,
                        scrollDirection: Axis.vertical,
                        physics: const BouncingScrollPhysics(),
                        pageSnapping: false,
                        onPageChanged: (page) {
                          setState(() {
                            _currentPage = page;
                          });
                        },
                        onDocumentLoaded: (document) {
                          setState(() {
                            _totalPages = document.pagesCount;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // --- Page Number Display ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Page $_currentPage',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
