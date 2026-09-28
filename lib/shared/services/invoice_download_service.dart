import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api/api_client.dart';

/// Downloads a tax invoice PDF from the backend and hands it to the OS share
/// sheet — covers both "download" (Save to Files) and "send" (share via any
/// installed app) with a single, already-available flow, since a bare mobile
/// download has nowhere obvious to land.
class InvoiceDownloadService {
  static Future<void> downloadAndShare(
    BuildContext context, {
    required String endpoint,
    required String fileName,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Preparing invoice…'), duration: Duration(seconds: 2)),
    );

    final result = await ApiClient().downloadBinary(endpoint);

    if (!result.success || result.bytes == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to download invoice.')),
      );
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(result.bytes!, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf', name: fileName)],
        text: 'EBIC Invoice',
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to save invoice. Please try again.')),
      );
    }
  }
}
