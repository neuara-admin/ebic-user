import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';

/// Modal bottom sheet allowing users to upload, replace, or remove their
/// profile photo using the device camera or gallery, without extraneous presets or URL inputs.
class AvatarPickerSheet extends StatefulWidget {
  final String? currentAvatarUrl;
  final String? uploadEndpoint;
  final bool updateCurrentUser;

  const AvatarPickerSheet({
    super.key,
    this.currentAvatarUrl,
    this.uploadEndpoint,
    this.updateCurrentUser = true,
  });

  static Future<dynamic> show(
    BuildContext context, {
    String? currentAvatarUrl,
    String? uploadEndpoint,
    bool updateCurrentUser = true,
  }) {
    return showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AvatarPickerSheet(
        currentAvatarUrl: currentAvatarUrl,
        uploadEndpoint: uploadEndpoint,
        updateCurrentUser: updateCurrentUser,
      ),
    );
  }

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  final ApiClient _api = ApiClient();
  final AuthService _auth = AuthService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  String _loadingMessage = '';
  late String? _currentAvatar;

  @override
  void initState() {
    super.initState();
    _currentAvatar = widget.currentAvatarUrl;
  }

  bool get _hasPhoto => _currentAvatar != null && _currentAvatar!.trim().isNotEmpty;

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() {
        _isLoading = true;
        _loadingMessage = _hasPhoto ? 'Replacing photo...' : 'Uploading photo...';
      });

      final bytes = await pickedFile.readAsBytes();
      final rawExt = pickedFile.name.contains('.')
          ? pickedFile.name.split('.').last.toLowerCase()
          : 'jpg';
      final cleanExt = (rawExt == 'png' || rawExt == 'webp') ? rawExt : 'jpg';
      final filename = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$cleanExt';

      final endpoint = widget.uploadEndpoint ?? ApiEndpoints.uploadAvatar;
      final res = await _api.uploadMultipart<Map<String, dynamic>>(
        endpoint,
        fileBytes: bytes,
        filename: filename,
        contentType: MediaType('image', cleanExt == 'png' ? 'png' : cleanExt == 'webp' ? 'webp' : 'jpeg'),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.success && res.data != null) {
        final newUrl = res.data!['avatarUrl'] as String?;
        if (widget.updateCurrentUser) {
          final updatedUser = Map<String, dynamic>.from(_auth.user ?? {});
          updatedUser['avatarUrl'] = newUrl;
          _auth.updateCurrentUser(updatedUser);

          await TokenStorage.saveUser(
            id: res.data!['id'] ?? updatedUser['id'] ?? '',
            phone: updatedUser['phone'] ?? '',
            name: updatedUser['name'],
            email: updatedUser['email'],
            avatarUrl: newUrl,
          );
        }

        if (!mounted) return;
        Navigator.pop(context, newUrl ?? true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primary,
            content: Text('Profile photo updated successfully!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(res.error?.message ?? 'Failed to upload photo. Please try again.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Could not access photo: ${e.toString()}'),
        ),
      );
    }
  }

  Future<void> _removeAvatar() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Removing photo...';
    });

    try {
      if (widget.updateCurrentUser) {
        final res = await _api.patch<Map<String, dynamic>>(
          ApiEndpoints.me,
          body: {'avatarUrl': null},
        );

        if (!mounted) return;
        setState(() => _isLoading = false);

        if (res.success && res.data != null) {
          final updatedUser = Map<String, dynamic>.from(_auth.user ?? {});
          updatedUser['avatarUrl'] = null;
          _auth.updateCurrentUser(updatedUser);

          await TokenStorage.saveUser(
            id: res.data!['id'] ?? updatedUser['id'] ?? '',
            phone: updatedUser['phone'] ?? '',
            name: updatedUser['name'],
            email: updatedUser['email'],
            avatarUrl: null,
          );

          if (!mounted) return;
          Navigator.pop(context, '');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.primary,
              content: Text('Profile photo removed'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.danger,
              content: Text(res.error?.message ?? 'Failed to remove photo.'),
            ),
          );
        }
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.pop(context, '');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Failed to remove photo. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final resolvedAvatarUrl = AppConfig.resolveMediaUrl(_currentAvatar);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 28 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasPhoto ? 'Profile Photo' : 'Upload Profile Photo',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hasPhoto
                          ? 'Replace with a new image or remove current photo.'
                          : 'Choose an image from camera or gallery.',
                      style: const TextStyle(fontSize: 13, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.slate500),
                onPressed: _isLoading ? null : () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Avatar Preview
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _hasPhoto ? AppColors.primary : AppColors.slate200,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _hasPhoto && resolvedAvatarUrl != null
                        ? Image.network(
                            resolvedAvatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.primarySubtle,
                              child: const Icon(Icons.person_rounded, size: 48, color: AppColors.primary),
                            ),
                          )
                        : Container(
                            color: AppColors.slate100,
                            child: const Icon(Icons.add_a_photo_rounded, size: 36, color: AppColors.slate400),
                          ),
                  ),
                ),
                if (_isLoading)
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.45),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isLoading) ...[
            const SizedBox(height: 12),
            Text(
              _loadingMessage,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Options List
          if (!_isLoading) ...[
            _buildActionTile(
              icon: Icons.camera_alt_rounded,
              iconColor: AppColors.primary,
              iconBgColor: AppColors.primarySubtle,
              title: 'Take Photo',
              subtitle: 'Capture a new picture using your camera',
              onTap: () => _pickAndUploadImage(ImageSource.camera),
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              icon: Icons.photo_library_rounded,
              iconColor: const Color(0xFF0284C7),
              iconBgColor: const Color(0xFFE0F2FE),
              title: _hasPhoto ? 'Replace from Gallery' : 'Choose from Gallery',
              subtitle: 'Select an existing image from your device',
              onTap: () => _pickAndUploadImage(ImageSource.gallery),
            ),
            if (_hasPhoto) ...[
              const SizedBox(height: 12),
              _buildActionTile(
                icon: Icons.delete_outline_rounded,
                iconColor: AppColors.danger,
                iconBgColor: const Color(0xFFFEE2E2),
                title: 'Remove Photo',
                subtitle: 'Delete current photo and revert to initials',
                isDanger: true,
                onTap: _removeAvatar,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return Material(
      color: isDanger ? const Color(0xFFFEF2F2) : AppColors.slate50,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDanger ? const Color(0xFFFECACA) : AppColors.slate200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDanger ? AppColors.danger : AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDanger ? AppColors.danger.withOpacity(0.8) : AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDanger ? AppColors.danger : AppColors.slate400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
