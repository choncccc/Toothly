import 'dart:io';

import 'package:flutter/material.dart';

/// What the user decided after looking at a freshly taken photo.
enum PhotoReviewChoice { use, retake }

/// Full-screen look at a photo straight from the camera, so it can be retaken
/// before it is attached. Pops [PhotoReviewChoice.use] or
/// [PhotoReviewChoice.retake]; backing out pops null (discard).
class PhotoReviewView extends StatelessWidget {
  final File photo;

  const PhotoReviewView({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Review photo'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(child: Image.file(photo, fit: BoxFit.contain)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () =>
                          Navigator.pop(context, PhotoReviewChoice.retake),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retake'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF8F6BFF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () =>
                          Navigator.pop(context, PhotoReviewChoice.use),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Use photo'),
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
}
