import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kisekae/core/notifications/theme/app_theme.dart';
import 'package:kisekae/models/seller_product.dart';
import 'package:kisekae/services/seller_product.dart';

class ProductGalleryScreen extends StatefulWidget {
  final int storeId;
  final int productId;
  final int variantId;
  final String variantName;
  final String? initialPrimaryImageUrl;

  const ProductGalleryScreen({
    super.key,
    required this.storeId,
    required this.productId,
    required this.variantId,
    this.variantName = '',
    this.initialPrimaryImageUrl,
  });

  @override
  State<ProductGalleryScreen> createState() => _ProductGalleryScreenState();
}

class _ProductGalleryScreenState extends State<ProductGalleryScreen> {
  final HandleProduct _productService = HandleProduct();
  final ImagePicker _picker = ImagePicker();

  List<ProductVariantImage> _images = [];

  bool _isLoadingImages = true;
  bool _isUploadingImages = false;
  final Set<int> _deletingImageIds = {};

  @override
  void initState() {
    super.initState();
    _fetchImages();
  }

  Future<void> _fetchImages() async {
    setState(() => _isLoadingImages = true);
    try {
      final images = await _productService.getVariantImages(
        storeId: widget.storeId,
        productId: widget.productId,
        variantId: widget.variantId,
      );
      if (mounted) {
        setState(() {
          _images = images;
          _isLoadingImages = false;
        });
      }
    } catch (e) {
      if (mounted && e is! DioException) {
        setState(() => _isLoadingImages = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load images: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickAndUploadImages() async {
    final int availableSlots = 10 - _images.length;
    if (availableSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 10 images allowed per variant.')),
      );
      return;
    }

    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      imageQuality: 85,
    );
    if (pickedFiles.isEmpty) return;

    if (pickedFiles.length > availableSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You can only select up to $availableSlots more image(s).',
          ),
        ),
      );
      return;
    }

    setState(() => _isUploadingImages = true);

    try {
      for (var i = 0; i < pickedFiles.length; i++) {
        final file = File(pickedFiles[i].path);
        await _productService.uploadVariantImage(
          storeId: widget.storeId,
          productId: widget.productId,
          variantId: widget.variantId,
          imageFile: file,
          order: _images.length + i,
        );
      }

      if (mounted) {
        await _fetchImages();
        setState(() => _isUploadingImages = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${pickedFiles.length} image(s) uploaded successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImages = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload images: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteImage(int imageId) async {
    final confirm = await _showConfirmDialog(
      title: "Delete Image?",
      content: "Are you sure you want to delete this photo?",
    );
    if (confirm != true) return;

    setState(() => _deletingImageIds.add(imageId));

    try {
      await _productService.deleteVariantImage(
        storeId: widget.storeId,
        productId: widget.productId,
        variantId: widget.variantId,
        imageId: imageId,
      );

      if (mounted) {
        setState(() {
          _images.removeWhere((img) => img.id == imageId);
          _deletingImageIds.remove(imageId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deletingImageIds.remove(imageId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete image: ${e.toString()}')),
        );
      }
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: ctx.cs.onSurface,
          ),
        ),
        content: Text(content, style: TextStyle(color: ctx.cs.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "CANCEL",
              style: TextStyle(color: ctx.appColors.mutedText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              "DELETE",
              style: TextStyle(
                color: ctx.cs.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final c = context.appColors;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context, true),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: cs.onSurface, width: 2),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: cs.onSurface,
            ),
          ),
        ),
        title: Text(
          widget.variantName.isNotEmpty
              ? "Photos – ${widget.variantName}"
              : "Variant Photos",
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Variant Images",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      "${_images.length} of 10 uploaded",
                      style: TextStyle(fontSize: 12, color: c.mutedText),
                    ),
                  ],
                ),
                if (_images.length < 10)
                  TextButton.icon(
                    onPressed: _isUploadingImages ? null : _pickAndUploadImages,
                    icon: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: cs.primary,
                      size: 20,
                    ),
                    label: Text(
                      "Add Photos",
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            _isLoadingImages
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: cs.primary),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.border),
                    ),
                    child: Column(
                      children: [
                        if (_isUploadingImages) ...[
                          LinearProgressIndicator(color: cs.primary),
                          const SizedBox(height: 12),
                        ],
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1.0,
                              ),
                          itemCount:
                              _images.length + (_images.length < 10 ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _images.length) {
                              return GestureDetector(
                                onTap: _isUploadingImages
                                    ? null
                                    : _pickAndUploadImages,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: cs.primary.withAlpha(128),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_rounded,
                                        color: cs.primary,
                                        size: 28,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Add More",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final image = _images[index];
                            final isDeleting = _deletingImageIds.contains(
                              image.id,
                            );

                            return Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      image.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: cs.surfaceContainerHighest,
                                        child: Icon(
                                          Icons.broken_image,
                                          color: c.mutedText,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: isDeleting
                                        ? null
                                        : () => _deleteImage(image.id),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: cs.scrim.withAlpha(140),
                                        shape: BoxShape.circle,
                                      ),
                                      child: isDeleting
                                          ? SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: cs.onPrimary,
                                              ),
                                            )
                                          : Icon(
                                              Icons.close_rounded,
                                              color: cs.onPrimary,
                                              size: 16,
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
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
