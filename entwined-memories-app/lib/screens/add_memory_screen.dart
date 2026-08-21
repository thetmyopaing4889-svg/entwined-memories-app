import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/memory.dart';
import '../services/memory_service.dart';
import '../services/youtube_service.dart';
import '../services/cloudinary_service.dart';
import '../services/display_media_service.dart';
import '../services/photo_variant_service.dart';
import '../services/original_vault_service.dart';

enum _MediaType { none, photo, video }

class AddMemoryScreen extends StatefulWidget {
  final Memory? memory;
  const AddMemoryScreen({super.key, this.memory});

  @override
  State<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends State<AddMemoryScreen> {
  final _noteController = TextEditingController();
  final _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedMood = '😊';

  File? _mediaFile;
  final List<File> _photoFiles = [];
  final List<String?> _photoMimeTypes = [];
  String? _mediaMimeType;
  _MediaType _mediaType = _MediaType.none;
  String? _existingImageUrl;
  String? _existingThumbnailUrl;
  String? _existingVideoId;

  bool _isSaving = false;
  String _uploadStatus = '';
  double? _uploadProgress; // null = indeterminate, 0.0-1.0 = video % done
  bool _uploadCancelled = false;

  bool get _isEditing => widget.memory != null;

  static const _moods = ['😊', '😍', '🥹', '😄', '🥰', '😌', '🎉', '💕'];
  static const int _maxNote = 500;
  static const int _maxPhotosPerMemory = 10;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final m = widget.memory!;
      _noteController.text = m.note;
      _nameController.text = m.createdBy;
      _selectedDate = m.date;
      _selectedMood = m.mood;
      _existingImageUrl = m.imageUrl;
      _existingThumbnailUrl = m.thumbnailUrl;
      _existingVideoId = m.videoId;
      if (m.hasVideo) {
        _mediaType = _MediaType.video;
      } else if (m.hasImage) {
        _mediaType = _MediaType.photo;
      }
    } else {
      _loadSavedName();
    }
  }

  Future<void> _loadSavedName() async {
    final saved = await MemoryService.loadCreatorName();
    if (saved.isNotEmpty && mounted) {
      setState(() => _nameController.text = saved);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      // Keep the gallery source untouched. The upload pipeline creates its own
      // short-lived thumbnail/display copies after this selection.
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isEmpty || !mounted) return;

      final existingPaths = _photoFiles.map((file) => file.path).toSet();
      final additions = picked
          .where((file) => existingPaths.add(file.path))
          .toList(growable: false);
      final remaining = _maxPhotosPerMemory - _photoFiles.length;
      if (remaining <= 0) {
        _showSnack(
            'Memory တစ်ခုလျှင် ပုံ $_maxPhotosPerMemory ပုံအထိပဲရွေးလို့ရတယ်');
        return;
      }

      final accepted = additions.take(remaining).toList(growable: false);
      setState(() {
        _photoFiles.addAll(accepted.map((file) => File(file.path)));
        _photoMimeTypes.addAll(accepted.map((file) => file.mimeType));
        _mediaFile = null;
        _mediaMimeType = null;
        _mediaType = _MediaType.photo;
        _existingImageUrl = null;
        _existingThumbnailUrl = null;
        _existingVideoId = null;
      });

      if (additions.length > remaining) {
        _showSnack(
            'ပထမ $remaining ပုံသာ ထည့်ပေးလိုက်တယ် (max $_maxPhotosPerMemory ပုံ)');
      }
    } catch (_) {
      if (mounted) _showSnack('Gallery ဖွင့်မရဘူး။ Permission စစ်ပါ။');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 15),
      );
      if (picked != null && mounted) {
        setState(() {
          _mediaFile = File(picked.path);
          _photoFiles.clear();
          _photoMimeTypes.clear();
          _mediaMimeType = picked.mimeType;
          _mediaType = _MediaType.video;
          _existingImageUrl = null;
          _existingThumbnailUrl = null;
          _existingVideoId = null;
        });
      }
    } catch (_) {
      if (mounted) _showSnack('Gallery ဖွင့်မရဘူး။ Permission စစ်ပါ။');
    }
  }

  void _removeMedia() => setState(() {
        _mediaFile = null;
        _photoFiles.clear();
        _photoMimeTypes.clear();
        _mediaMimeType = null;
        _mediaType = _MediaType.none;
        _existingImageUrl = null;
        _existingThumbnailUrl = null;
        _existingVideoId = null;
      });

  void _removeSelectedPhoto(int index) {
    setState(() {
      _photoFiles.removeAt(index);
      _photoMimeTypes.removeAt(index);
      if (_photoFiles.isEmpty) _mediaType = _MediaType.none;
    });
  }

  Future<void> _archiveSelectedOriginals() async {
    for (var i = 0; i < _photoFiles.length; i++) {
      if (mounted) {
        setState(() {
          _uploadStatus =
              'ပုံ ${i + 1} / ${_photoFiles.length} မူရင်းကို vault သို့ကူးနေတယ်...';
        });
      }
      await OriginalVaultService.archiveSelectedPhoto(
        source: _photoFiles[i],
        memoryDate: _selectedDate,
        mimeType: i < _photoMimeTypes.length ? _photoMimeTypes[i] : null,
      );
    }
  }

  Future<void> _archiveSelectedVideo() async {
    final video = _mediaFile;
    if (video == null) {
      throw StateError('ရွေးထားတဲ့မူရင်း Video ကို မတွေ့တော့ဘူး။');
    }
    if (mounted) {
      setState(() {
        _uploadStatus = 'Video မူရင်းကို vault သို့ကူးနေတယ်...';
        _uploadProgress = null;
      });
    }
    await OriginalVaultService.archiveSelectedVideo(
      source: video,
      memoryDate: _selectedDate,
      mimeType: _mediaMimeType,
    );
  }

  Future<MemoryPhoto> _uploadPhoto(
    File source, {
    required int index,
    required int total,
  }) async {
    PhotoUploadVariants? variants;
    CloudinaryImageUpload? thumbnail;
    try {
      if (mounted) {
        setState(
            () => _uploadStatus = 'ပုံ $index / $total ကို ပြင်ဆင်နေတယ်...');
      }
      variants = await PhotoVariantService.createVariants(source);

      if (mounted) {
        setState(() =>
            _uploadStatus = 'ပုံ $index / $total thumbnail ကို တင်နေတယ်...');
      }
      thumbnail = await CloudinaryService.uploadMemoryImage(
        variants.thumbnailFile,
      );

      if (mounted) {
        setState(() =>
            _uploadStatus = 'ပုံ $index / $total full photo ကို တင်နေတယ်...');
      }
      final display = await DisplayMediaService.uploadDisplayWebp(
        variants.displayFile,
      );

      return MemoryPhoto(
        imageUrl: thumbnail.secureUrl,
        thumbnailUrl: thumbnail.secureUrl,
        displayMediaKey: display.key,
        mediaProviderVersion: 1,
        imagePublicId: thumbnail.publicId,
      );
    } catch (_) {
      // The gallery item is not added to [uploadedPhotos] until both providers
      // succeed, so clean a thumbnail that failed before its R2 pair existed.
      if (thumbnail != null) {
        try {
          await MemoryService.cleanupImageAssets(
            imagePublicId: thumbnail.publicId,
            imageUrl: thumbnail.secureUrl,
          );
        } catch (_) {
          // Idempotent Worker cleanup can be retried later if the network drops.
        }
      }
      rethrow;
    } finally {
      await variants?.dispose();
    }
  }

  Future<void> _saveMemory() async {
    final note = _noteController.text.trim();
    final name = _nameController.text.trim();

    if (note.isEmpty) {
      _showSnack('Memory note မရေးသေးဘူး');
      return;
    }
    if (name.isEmpty) {
      _showSnack('ဘယ်သူ ထည့်တာလဲ ရေးပါ (Dad / Mom)');
      return;
    }

    setState(() {
      _isSaving = true;
      _uploadStatus = '';
      _uploadProgress = null;
      _uploadCancelled = false;
    });

    final uploadedPhotos = <MemoryPhoto>[];
    final replacedPhotos = <MemoryPhoto>[];
    var firestoreSaved = false;

    try {
      var finalPhotos = _isEditing ? widget.memory!.allPhotos : <MemoryPhoto>[];
      String? finalVideoId = _existingVideoId;
      String? finalProcessingStatus = widget.memory?.processingStatus;

      if (_photoFiles.isNotEmpty) {
        // A selected source photo must be preserved locally before any lossy
        // variant is created or any cloud provider receives data. A failure
        // throws here and aborts the whole memory save without remote uploads.
        await _archiveSelectedOriginals();

        if (_isEditing) replacedPhotos.addAll(widget.memory!.allPhotos);
        for (var i = 0; i < _photoFiles.length; i++) {
          uploadedPhotos.add(await _uploadPhoto(
            _photoFiles[i],
            index: i + 1,
            total: _photoFiles.length,
          ));
        }
        finalPhotos = uploadedPhotos;
        finalVideoId = null;
        finalProcessingStatus = null;
      } else if (_mediaFile != null && _mediaType == _MediaType.video) {
        // A selected source video must be preserved locally before YouTube
        // receives data. A vault failure aborts this save with no remote upload.
        await _archiveSelectedVideo();

        if (_isEditing) replacedPhotos.addAll(widget.memory!.allPhotos);
        setState(() {
          _uploadStatus = 'YouTube upload session ကိုစတင်နေတယ်...';
          _uploadProgress = 0;
        });
        final dateStr =
            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
        final finalVideo = await YouTubeService.uploadVideo(
          videoFile: _mediaFile!,
          title: 'Memory $dateStr',
          description: note,
          mimeType: _mediaMimeType,
          isCancelled: () => _uploadCancelled,
          onStage: (stage) {
            if (!mounted) return;
            setState(() {
              _uploadStatus = switch (stage) {
                YouTubeUploadStage.uploading => 'Video YouTube ကို တင်နေတယ်...',
                YouTubeUploadStage.finalizing =>
                  'YouTube က upload ကိုအတည်ပြုနေတယ်...',
                YouTubeUploadStage.recovering =>
                  'Network ပြတ်သွားလို့ YouTube upload ကို ပြန်ဆက်နေတယ်...',
              };
            });
          },
          onProgress: (p) {
            if (!mounted) return;
            setState(() {
              _uploadProgress = p;
              _uploadStatus = p >= 1
                  ? 'Video YouTube သို့တင်ပြီးပြီ။ Memory သိမ်းနေတယ်...'
                  : 'Video YouTube ကို တင်နေတယ်... ${(p * 100).toStringAsFixed(0)}%';
            });
          },
        );
        finalVideoId = finalVideo.videoId;
        finalProcessingStatus = finalVideo.processingStatus;
        finalPhotos = <MemoryPhoto>[];
      }

      final cover = finalPhotos.isEmpty ? null : finalPhotos.first;
      await MemoryService.saveCreatorName(name);

      final memory = Memory(
        id: _isEditing ? widget.memory!.id : const Uuid().v4(),
        note: note,
        date: _selectedDate,
        createdBy: name,
        mood: _selectedMood,
        imageUrl: cover?.imageUrl,
        thumbnailUrl: cover?.thumbnailUrl,
        displayMediaKey: cover?.displayMediaKey,
        mediaProviderVersion: cover?.mediaProviderVersion,
        imagePublicId: cover?.imagePublicId,
        photos: finalPhotos,
        videoId: finalVideoId,
        processingStatus: finalProcessingStatus,
      );

      if (_isEditing) {
        await MemoryService.updateMemory(memory);
        firestoreSaved = true;
        // Only after Firestore points at the replacement media do we remove
        // old copies. A cleanup interruption cannot make the memory disappear.
        if (replacedPhotos.isNotEmpty) {
          try {
            await MemoryService.cleanupImageAssetsBatch(replacedPhotos);
          } catch (_) {
            // The new memory is valid. A failed idempotent cleanup is safer
            // than rolling back the updated Firestore document.
          }
        }
        if (mounted) Navigator.pop(context, true);
      } else {
        await MemoryService.addMemory(memory);
        firestoreSaved = true;
        if (mounted) Navigator.pop(context);
      }
    } on YouTubeUploadCancelled {
      if (mounted) _showSnack('Upload ကို ရပ်လိုက်ပါပြီ');
    } catch (e) {
      // The Firestore document is created only after every photo copy upload
      // succeeds. On any failure, remove all new remote copies as a batch.
      if (!firestoreSaved && uploadedPhotos.isNotEmpty) {
        try {
          await MemoryService.cleanupImageAssetsBatch(uploadedPhotos);
        } catch (_) {
          // The Worker delete route is idempotent, so a future cleanup retry is
          // safe even if a mobile network interruption happened here.
        }
      }
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _uploadStatus = '';
          _uploadProgress = null;
          _uploadCancelled = false;
        });
      }
    }
  }

  void _cancelUpload() {
    setState(() {
      _uploadCancelled = true;
      _uploadStatus = 'ရပ်နေတယ်...';
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFE8A0B4),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        title: Text(_isEditing ? 'Memory ပြင်မယ်' : 'Memory အသစ်'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        actions: [
          if (!_isSaving)
            TextButton(
              onPressed: _saveMemory,
              child: const Text(
                'သိမ်းမယ်',
                style: TextStyle(
                    color: Color(0xFFE8A0B4), fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: _isSaving
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_uploadProgress != null && _uploadProgress! > 0)
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator(
                          value: _uploadProgress!.clamp(0.0, 1.0),
                          color: const Color(0xFFE8A0B4),
                          backgroundColor: const Color(0xFFFFE0E8),
                          strokeWidth: 5,
                        ),
                      )
                    else
                      const CircularProgressIndicator(color: Color(0xFFE8A0B4)),
                    const SizedBox(height: 24),
                    Text(
                      _uploadStatus.isEmpty ? 'သိမ်းနေတယ်...' : _uploadStatus,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, color: Color(0xFF3D2C33), height: 1.6),
                    ),
                    if (_mediaType == _MediaType.video &&
                        _uploadProgress != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Network နှေးရင် video upload ကြာနိုင်ပါတယ်',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 24),
                      if (!_uploadCancelled)
                        OutlinedButton(
                          onPressed: _cancelUpload,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          child: const Text('ရပ်မယ်'),
                        ),
                    ],
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Date ──────────────────────────────────────────────
                  const _Label('နေ့ရက်'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: Color(0xFFE8A0B4), size: 18),
                        const SizedBox(width: 10),
                        Text(_formatDate(_selectedDate),
                            style: const TextStyle(
                                fontSize: 15, color: Color(0xFF3D2C33))),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Mood ──────────────────────────────────────────────
                  const _Label('Mood'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _moods
                        .map((m) => GestureDetector(
                              onTap: () => setState(() => _selectedMood = m),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _selectedMood == m
                                      ? const Color(0xFFFFD6E4)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedMood == m
                                        ? const Color(0xFFE8A0B4)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Text(m,
                                    style: const TextStyle(fontSize: 28)),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── Note ──────────────────────────────────────────────
                  const _Label('Memory'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _noteController,
                      maxLines: 5,
                      maxLength: _maxNote,
                      decoration: const InputDecoration(
                        hintText: 'ဒီနေ့ ဘာဖြစ်ခဲ့လဲ ရေးပါ...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Media ─────────────────────────────────────────────
                  const _Label('ဓာတ်ပုံ / Video'),
                  const SizedBox(height: 8),
                  _buildMediaSection(),
                  const SizedBox(height: 20),

                  // ── Name ──────────────────────────────────────────────
                  const _Label('ဘယ်သူ ထည့်တာလဲ'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'Dad / Mom / နာမည်',
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildMediaSection() {
    if (_photoFiles.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _photoFiles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) => ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_photoFiles[index], fit: BoxFit.cover),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => _removeSelectedPhoto(index),
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(5),
                          child:
                              Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${_photoFiles.length} / $_maxPhotosPerMemory ပုံရွေးပြီး',
                style: const TextStyle(
                  color: Color(0xFF8B3A52),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _photoFiles.length >= _maxPhotosPerMemory
                    ? null
                    : _pickPhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('ထပ်ရွေးမယ်'),
              ),
            ],
          ),
        ],
      );
    }

    // Local video file selected
    if (_mediaFile != null && _mediaType == _MediaType.video) {
      return _mediaTile(
        child: Container(
          color: Colors.black87,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam, color: Colors.white, size: 48),
                SizedBox(height: 8),
                Text('Video ရွေးပြီးပြီ',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                SizedBox(height: 4),
                Text('မူရင်း Vault → YouTube',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ),
        onRemove: _removeMedia,
      );
    }

    // Local photo selected
    if (_mediaFile != null && _mediaType == _MediaType.photo) {
      return _mediaTile(
        child: Image.file(_mediaFile!, fit: BoxFit.cover),
        onRemove: _removeMedia,
      );
    }

    // Existing YouTube video (edit mode)
    if (_existingVideoId != null) {
      return _mediaTile(
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            Image.network(
              YouTubeService.getThumbnailUrl(_existingVideoId!),
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.4)),
              child: const Icon(Icons.play_circle_filled,
                  color: Colors.white, size: 48),
            ),
          ],
        ),
        onRemove: _removeMedia,
      );
    }

    // Existing Cloudinary image (edit mode)
    if ((_existingThumbnailUrl ?? _existingImageUrl) != null) {
      return _mediaTile(
        child: Image.network(
          _existingThumbnailUrl ?? _existingImageUrl!,
          fit: BoxFit.cover,
        ),
        onRemove: _removeMedia,
      );
    }

    // Picker buttons
    return Row(
      children: [
        Expanded(
          child: _pickerBtn(
            icon: Icons.photo_library_outlined,
            label: 'ဓာတ်ပုံများ',
            sub: 'အများဆုံး 10 ပုံ',
            onTap: _pickPhoto,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _pickerBtn(
            icon: Icons.videocam_outlined,
            label: 'Video',
            sub: 'Vault → YouTube',
            onTap: _pickVideo,
          ),
        ),
      ],
    );
  }

  Widget _pickerBtn({
    required IconData icon,
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFD6E4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFE8A0B4), size: 28),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3D2C33))),
            Text(sub,
                style: const TextStyle(fontSize: 11, color: Color(0xFFB0889A))),
          ],
        ),
      ),
    );
  }

  Widget _mediaTile({required Widget child, required VoidCallback onRemove}) {
    return SizedBox(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: const Color(0xFFE8A0B4)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF3D2C33)),
    );
  }
}
