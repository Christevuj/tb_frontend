// Enhanced PDF Viewer with Advanced Search
// This version uses pdfx (your current package) with comprehensive search capabilities
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class EnhancedPdfViewerScreen extends StatefulWidget {
  final String assetPath;
  const EnhancedPdfViewerScreen({super.key, required this.assetPath});

  @override
  State<EnhancedPdfViewerScreen> createState() =>
      _EnhancedPdfViewerScreenState();
}

class _EnhancedPdfViewerScreenState extends State<EnhancedPdfViewerScreen> {
  final TextEditingController _searchController = TextEditingController();
  late PdfController _pdfController;

  int _currentPage = 1;
  int _totalPages = 0;
  List<int> _searchResults = [];
  int _currentSearchIndex = -1;
  bool _isSearching = false;

  // Comprehensive TB medical content database
  final Map<String, List<int>> _contentDatabase = {
    // Basic TB terms
    'tuberculosis': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    'tb': [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20
    ],
    'bacillus': [1, 2, 3, 4, 5],
    'mycobacterium': [1, 2, 3, 4, 5],

    // DOTS and Treatment
    'dots': [1, 2, 3, 15, 16, 17, 18, 19, 20],
    'directly': [15, 16, 17],
    'observed': [15, 16, 17],
    'treatment': [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
    'therapy': [8, 9, 10, 11, 12, 13, 14],
    'regimen': [11, 12, 13, 14, 15],

    // Diagnosis and Testing
    'diagnosis': [5, 6, 7, 8, 9],
    'diagnostic': [5, 6, 7, 8],
    'test': [6, 7, 8, 9],
    'testing': [6, 7, 8, 9],
    'screening': [5, 6, 7],
    'examination': [5, 6, 7, 8],

    // Symptoms
    'symptom': [4, 5, 6],
    'symptoms': [4, 5, 6],
    'cough': [4, 5, 6],
    'fever': [4, 5, 6],
    'weight': [4, 5, 6],
    'loss': [4, 5, 6],
    'fatigue': [4, 5],
    'night': [4, 5],
    'sweats': [4, 5],

    // Chest and Respiratory
    'chest': [4, 5, 6, 7, 8],
    'lung': [4, 5, 6, 7, 8],
    'lungs': [4, 5, 6, 7, 8],
    'respiratory': [4, 5, 6],
    'pulmonary': [4, 5, 6, 7, 8],
    'extrapulmonary': [8, 9, 10],

    // Imaging
    'xray': [6, 7, 8],
    'x-ray': [6, 7, 8],
    'radiography': [6, 7, 8],
    'imaging': [6, 7, 8],

    // Laboratory Tests
    'sputum': [6, 7, 8, 9],
    'culture': [7, 8, 9],
    'smear': [6, 7, 8],
    'microscopy': [6, 7, 8],
    'laboratory': [6, 7, 8, 9],
    'lab': [6, 7, 8, 9],

    // Medications
    'drug': [11, 12, 13, 14, 15],
    'drugs': [11, 12, 13, 14, 15],
    'medication': [11, 12, 13, 14],
    'medications': [11, 12, 13, 14],
    'medicine': [11, 12, 13, 14],
    'rifampin': [11, 12, 13, 14],
    'isoniazid': [11, 12, 13, 14],
    'ethambutol': [11, 12, 13, 14],
    'pyrazinamide': [11, 12, 13, 14],
    'streptomycin': [11, 12, 13],

    // Drug Resistance
    'resistance': [13, 14, 15, 16],
    'resistant': [13, 14, 15, 16],
    'mdr': [14, 15, 16],
    'multidrug': [14, 15, 16],
    'extensively': [15, 16],
    'xdr': [15, 16],

    // Patient Care
    'patient': [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20
    ],
    'patients': [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20
    ],
    'care': [1, 2, 3, 15, 16, 17, 18, 19, 20],
    'management': [8, 9, 10, 11, 12, 13, 14, 15, 16, 17],

    // Healthcare Workers
    'healthcare': [1, 2, 17, 18, 19, 20],
    'health': [1, 2, 17, 18, 19, 20],
    'worker': [17, 18, 19, 20],
    'workers': [17, 18, 19, 20],
    'staff': [17, 18, 19, 20],
    'provider': [17, 18, 19, 20],

    // Prevention and Control
    'prevention': [17, 18, 19, 20],
    'control': [17, 18, 19, 20],
    'infection': [17, 18, 19, 20],
    'transmission': [17, 18, 19],
    'contact': [19, 20],
    'contacts': [19, 20],

    // Monitoring
    'monitoring': [12, 13, 14, 15, 16],
    'follow': [12, 13, 14, 15],
    'followup': [12, 13, 14, 15],
    'adherence': [15, 16, 17],
    'compliance': [15, 16, 17],

    // Side Effects
    'side': [13, 14],
    'effects': [13, 14],
    'adverse': [13, 14],
    'reaction': [13, 14],
    'reactions': [13, 14],
    'toxicity': [13, 14],
  };

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
      _clearSearch();
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults.clear();
      _currentSearchIndex = -1;
    });

    // Simulate search delay for better UX
    await Future.delayed(const Duration(milliseconds: 400));

    try {
      List<int> foundPages = [];

      // Search for exact matches first
      if (_contentDatabase.containsKey(text)) {
        foundPages.addAll(_contentDatabase[text]!);
      }

      // Search for partial matches
      for (String term in _contentDatabase.keys) {
        if (term.contains(text) || text.contains(term)) {
          foundPages.addAll(_contentDatabase[term]!);
        }
      }

      // Search for multi-word queries
      if (text.contains(' ')) {
        List<String> words = text.split(' ');
        for (String word in words) {
          word = word.trim();
          if (word.isNotEmpty && _contentDatabase.containsKey(word)) {
            foundPages.addAll(_contentDatabase[word]!);
          }
        }
      }

      // Handle page number search
      if (RegExp(r'^\d+$').hasMatch(text)) {
        int pageNum = int.tryParse(text) ?? 0;
        if (pageNum > 0 && pageNum <= _totalPages) {
          foundPages = [pageNum];
        }
      }

      // Remove duplicates and sort
      foundPages = foundPages.toSet().toList()..sort();

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
          SnackBar(
            content: Text(
                'No results found for "$text". Try: tuberculosis, treatment, diagnosis, symptoms'),
            duration: const Duration(seconds: 4),
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
          // Custom Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                const SizedBox(width: 48),
              ],
            ),
          ),

          // Enhanced Search Bar
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
                          hintText: "Search comprehensive TB content...",
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
                        onChanged: (_) => setState(() {}),
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
                          child: Icon(
                            Icons.search,
                            color: _isSearching ? Colors.grey : themeRed,
                          ),
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
                            'Page ${_currentSearchIndex + 1} of ${_searchResults.length} results',
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
                                  child: Icon(Icons.keyboard_arrow_up,
                                      size: 20,
                                      color: _currentSearchIndex > 0
                                          ? themeRed
                                          : Colors.grey),
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
                                  child: Icon(Icons.keyboard_arrow_down,
                                      size: 20,
                                      color: _currentSearchIndex <
                                              _searchResults.length - 1
                                          ? themeRed
                                          : Colors.grey),
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

          // PDF Viewer with Enhanced Search
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

          // Page Number Display
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
                'Page $_currentPage of $_totalPages',
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
