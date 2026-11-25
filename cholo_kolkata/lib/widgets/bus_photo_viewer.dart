import 'package:flutter/material.dart';
import '../services/bus_photo_service.dart';

class BusPhotoGallery extends StatefulWidget {
  final String routeNo;
  final bool isAc;
  final String category;
  final double height;

  const BusPhotoGallery({
    super.key,
    required this.routeNo,
    this.isAc = false,
    this.category = 'West Bengal Transport Corporation',
    this.height = 190,
  });

  @override
  State<BusPhotoGallery> createState() => _BusPhotoGalleryState();
}

class _BusPhotoGalleryState extends State<BusPhotoGallery> {
  late final List<String> _photoUrls;
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _photoUrls = BusPhotoService.getPhotoUrls(widget.routeNo);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openFullScreen(BuildContext context, int initialIndex) {
    if (_photoUrls.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => _FullScreenPhotoViewer(
          photoUrls: _photoUrls,
          initialIndex: initialIndex,
          routeNo: widget.routeNo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_photoUrls.isEmpty) {
      return _buildPlaceholder();
    }

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // PageView of Bus Photos
            PageView.builder(
              controller: _pageController,
              itemCount: _photoUrls.length,
              onPageChanged: (idx) => setState(() => _currentPage = idx),
              itemBuilder: (ctx, idx) {
                final url = _photoUrls[idx];
                return GestureDetector(
                  onTap: () => _openFullScreen(context, idx),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: const Color(0xFF1E293B),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF2DD4BF),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return _buildPlaceholder();
                    },
                  ),
                );
              },
            ),

            // Top Gradient with Route Pill
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_rounded, size: 12, color: Color(0xFF2DD4BF)),
                    const SizedBox(width: 4),
                    Text(
                      'Bus ${widget.routeNo} Fleet',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Fullscreen expand button at top right
            Positioned(
              top: 8,
              right: 8,
              child: InkWell(
                onTap: () => _openFullScreen(context, _currentPage),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.70),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),

            // Bottom Gradient Overlay with pagination & info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dot Indicators
                  if (_photoUrls.length > 1)
                    Row(
                      children: List.generate(_photoUrls.length, (i) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          width: _currentPage == i ? 14 : 6,
                          height: 5,
                          decoration: BoxDecoration(
                            color: _currentPage == i ? const Color(0xFF2DD4BF) : Colors.white38,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    )
                  else
                    const Text(
                      'Tap photo to zoom',
                      style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
                    ),

                  // Counter or Label
                  Text(
                    _photoUrls.length > 1
                        ? '${_currentPage + 1} / ${_photoUrls.length}'
                        : 'Official Photo',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB2DFDB)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isAc ? Icons.airport_shuttle : Icons.directions_bus,
                size: 48,
                color: const Color(0xFF00695C),
              ),
              const SizedBox(height: 6),
              Text(
                widget.category.isNotEmpty ? widget.category : 'West Bengal Transport Corporation',
                style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                'Kolkata Metropolitan Area Transit Network',
                style: TextStyle(color: Colors.grey[600], fontSize: 10),
              ),
            ],
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Text(
                widget.isAc ? '❄️ AC Coach' : 'Standard Non-AC',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenPhotoViewer extends StatefulWidget {
  final List<String> photoUrls;
  final int initialIndex;
  final String routeNo;

  const _FullScreenPhotoViewer({
    required this.photoUrls,
    required this.initialIndex,
    required this.routeNo,
  });

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  late int _currentIndex;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bus ${widget.routeNo} Real Photo',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_currentIndex + 1} of ${widget.photoUrls.length} • Pinch to zoom',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photoUrls.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (ctx, i) {
          final url = widget.photoUrls[i];
          return Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.5,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2DD4BF)),
                  );
                },
                errorBuilder: (ctx, err, stack) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Unable to load photo', style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

