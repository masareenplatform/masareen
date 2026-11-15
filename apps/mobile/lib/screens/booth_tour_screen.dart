import 'package:flutter/material.dart';

class BoothTourScreen extends StatefulWidget {
  final String title;
  final List<String> images;
  const BoothTourScreen(
      {super.key, required this.title, required this.images});

  @override
  State<BoothTourScreen> createState() => _BoothTourScreenState();
}

class _BoothTourScreenState extends State<BoothTourScreen> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15)),
            const Text('360° booth tour · drag to look around',
                style: TextStyle(fontSize: 10, color: Colors.white60)),
          ],
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => InteractiveViewer(
              constrained: false,
              minScale: 1,
              maxScale: 3.5,
              boundaryMargin: const EdgeInsets.all(180),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 1.8,
                height: MediaQuery.of(context).size.height,
                child: Image.network(
                  widget.images[i],
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white)),
                  errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white54, size: 48)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Column(
              children: [
                const Icon(Icons.swipe, color: Colors.white70, size: 20),
                const SizedBox(height: 6),
                Text(
                    '${_page + 1} / ${widget.images.length} · pinch to zoom',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.images.length, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: active
                              ? cs.primary
                              : Colors.white.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(3)),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
