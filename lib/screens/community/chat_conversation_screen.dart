import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../controllers/community/community_controller.dart';
import '../../controllers/inventory/item_controller.dart';
import '../../controllers/inventory/supplier_controller.dart';
import '../../core/currency/currency_service.dart';
import '../../models/community/community_models.dart';
import '../../models/inventory/supplier_model.dart';
import '../inventory/purchase_order_screen.dart';

class ChatConversationScreen extends StatefulWidget {
  final ChatConversation conversation;

  const ChatConversationScreen({
    super.key,
    required this.conversation,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ItemController _itemCtrl = ItemController();

  List<MerchantMention> _mentionSuggestions = [];
  bool _showMentionPopup = false;
  int _lastMsgCount = 0;

  @override
  void initState() {
    super.initState();
    _itemCtrl.load();
    _msgCtrl.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ctrl = context.read<CommunityController>();
      final supplierCtrl = context.read<SupplierController>();
      supplierCtrl.load();
      await ctrl.refreshProfile();
      ctrl.setActiveConversation(widget.conversation.id);
      ctrl.markConversationAsRead(widget.conversation.id);

      // Auto scroll to bottom (last message) on opening chat
      Future.delayed(const Duration(milliseconds: 80), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      });
    });
  }

  bool _isMerchantInVendorMaster(
    SupplierController supplierCtrl, {
    String? name,
    String? taxId,
    String? phone,
    String? merchantId,
  }) {
    final cleanName = (name ?? '').trim().toLowerCase();
    final cleanTax = (taxId ?? '').trim().toLowerCase();
    final cleanPhone = (phone ?? '').trim().toLowerCase();
    final cleanId = (merchantId ?? '').trim().toLowerCase();

    return supplierCtrl.list.any((s) {
      final sName = s.supplierName.trim().toLowerCase();
      final sTax = (s.taxIdNumber ?? s.gstin ?? '').trim().toLowerCase();
      final sPhone = s.phone.trim().toLowerCase();
      final sCode = s.supplierCode.trim().toLowerCase();

      // Match by supplier / merchant name
      if (cleanName.isNotEmpty && sName == cleanName) return true;
      // Match by Tax ID / GSTIN
      if (cleanTax.isNotEmpty && cleanTax != 'registered' && cleanTax != 'tax id' && sTax.isNotEmpty && sTax == cleanTax) return true;
      // Match by Phone
      if (cleanPhone.isNotEmpty && sPhone.isNotEmpty && sPhone == cleanPhone) return true;
      // Match by code / id
      if (cleanId.isNotEmpty && (sCode == cleanId || s.id.toString() == cleanId)) return true;

      return false;
    });
  }

  bool _isMessageFromMe(ChatMessage msg, CommunityController ctrl) {
    final myCode = ctrl.currentMerchantId.trim().toLowerCase();
    final senderId = msg.senderId.trim().toLowerCase();

    // 1. Outlet code comparison (Globally unique username)
    if (myCode.isNotEmpty && senderId.isNotEmpty) {
      if (senderId == myCode) return true;
      if (senderId.startsWith('outlet') && myCode.startsWith('outlet') && senderId != myCode) {
        return false;
      }
    }

    // 2. Direct name comparison
    final myName = ctrl.currentMerchantName.trim().toLowerCase();
    final senderName = msg.senderName.trim().toLowerCase();
    if (myName.isNotEmpty && senderName.isNotEmpty) {
      if (senderName == myName) return true;
      if (myName != senderName) return false;
    }

    // 3. Direct GST comparison
    final myGst = ctrl.currentGstin.trim().toLowerCase();
    final senderGst = msg.senderGstin.trim().toLowerCase();
    if (myGst.isNotEmpty && senderGst.isNotEmpty) {
      if (senderGst == myGst) return true;
      if (senderGst != myGst) return false;
    }

    return senderId == myCode;
  }

  @override
  void dispose() {
    _msgCtrl.removeListener(_onTextChanged);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    try {
      context.read<CommunityController>().setActiveConversation(null);
    } catch (_) {}
    super.dispose();
  }

  void _onTextChanged() {
    final text = _msgCtrl.text;
    final selection = _msgCtrl.selection;
    if (!selection.isValid) return;

    final cursorPosition = selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPosition);
    final atIndex = textBeforeCursor.lastIndexOf('@');

    if (atIndex != -1) {
      final query = textBeforeCursor.substring(atIndex + 1);
      if (!query.contains(' ')) {
        final ctrl = context.read<CommunityController>();
        final results = ctrl.searchMentions(query);
        setState(() {
          _mentionSuggestions = results;
          _showMentionPopup = results.isNotEmpty;
        });
        return;
      }
    }

    if (_showMentionPopup) {
      setState(() => _showMentionPopup = false);
    }
  }

  void _applyMention(MerchantMention mention) {
    final text = _msgCtrl.text;
    final cursorPosition = _msgCtrl.selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPosition);
    final atIndex = textBeforeCursor.lastIndexOf('@');

    if (atIndex != -1) {
      final newText = '${text.substring(0, atIndex)}@${mention.handle} ${text.substring(cursorPosition)}';
      _msgCtrl.text = newText;
      _msgCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: atIndex + mention.handle.length + 2),
      );
    }

    setState(() => _showMentionPopup = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend({String? content, ChatAttachment? attachment}) async {
    final text = content?.trim() ?? _msgCtrl.text.trim();
    if (text.isEmpty && attachment == null) return;

    final ctrl = context.read<CommunityController>();
    final success = await ctrl.sendMessage(
      conversationId: widget.conversation.id,
      content: text,
      attachment: attachment,
    );

    if (success) {
      _msgCtrl.clear();
      setState(() => _showMentionPopup = false);
      _scrollToBottom();
    }
  }


  void _showMessageActionSheet(BuildContext context, ChatMessage message) {
    final ctrl = context.read<CommunityController>();
    final supplierCtrl = context.read<SupplierController>();
    final isMe = _isMessageFromMe(message, ctrl);
    final canRevoke = message.canDeleteForEveryone;
    final remainingMin = message.remainingRevokeMinutes;
    final isSavedInVendor = _isMerchantInVendorMaster(
      supplierCtrl,
      name: message.senderName,
      taxId: message.senderGstin,
      phone: message.senderPhone,
      merchantId: message.senderId,
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.copy_outlined),
                  title: const Text('Copy Text'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copied to clipboard')),
                    );
                  },
                ),
                if (!isMe && widget.conversation.isDirect == false)
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline, color: Colors.blueAccent),
                    title: Text('Message ${message.senderName} Privately'),
                    onTap: () {
                      Navigator.pop(ctx);
                      final directChat = ctrl.getOrCreateDirectChat(
                        recipientId: message.senderId,
                        recipientName: message.senderName,
                        recipientGstin: message.senderGstin,
                        recipientPhone: message.senderPhone,
                        recipientCity: message.senderCity,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatConversationScreen(conversation: directChat),
                        ),
                      );
                    },
                  ),
                if (!isMe && !isSavedInVendor)
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1, color: Colors.green),
                    title: Text('Save ${message.senderName} to Vendor Master'),
                    subtitle: const Text('Save contact & tax info to supplier directory'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _saveAsVendorMaster(
                        merchantName: message.senderName,
                        taxId: message.senderGstin,
                        phone: message.senderPhone,
                        city: message.senderCity,
                        state: message.senderCity,
                      );
                    },
                  ),
                const Divider(),
                // Delete for Me (Always allowed)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.orange),
                  title: const Text('Delete for Me'),
                  subtitle: const Text('Removes message from this device only'),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    await ctrl.deleteForMe(message);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Deleted from your view.')),
                    );
                  },
                ),

                // Edit Message (Allowed for own messages within 1 Hour)
                if (isMe && !message.isDeletedForEveryone && message.canEdit)
                  ListTile(
                    leading: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                    title: const Text('Edit Message'),
                    subtitle: Text('${message.remainingEditMinutes} minutes left to edit (within 1 hour)'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final editCtrl = TextEditingController(text: message.content);
                      final newText = await showDialog<String>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Edit Message'),
                          content: TextField(
                            controller: editCtrl,
                            autofocus: true,
                            maxLines: 4,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintText: 'Edit your message...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E40AF)),
                              onPressed: () => Navigator.pop(dCtx, editCtrl.text.trim()),
                              child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );

                      if (newText != null && newText.isNotEmpty && newText != message.content) {
                        await ctrl.editMessage(message, newText);
                      }
                    },
                  ),

                // Delete for Everyone (Allowed within 1 Hour)
                if (isMe && !message.isDeletedForEveryone)
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever,
                      color: canRevoke ? Colors.red : Colors.grey,
                    ),
                    title: Text(
                      'Delete for Everyone',
                      style: TextStyle(
                        color: canRevoke ? Colors.red : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      canRevoke
                          ? '$remainingMin minutes left (within 1 hour)'
                          : 'Expired (Cannot revoke after 1 hour)',
                      style: TextStyle(color: canRevoke ? Colors.red.shade700 : Colors.grey),
                    ),
                    enabled: canRevoke,
                    onTap: canRevoke
                        ? () async {
                            Navigator.pop(ctx);
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('Delete for Everyone?'),
                                content: const Text(
                                    'This message will be deleted for all participants in this chat.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () => Navigator.pop(dCtx, true),
                                    child: const Text('Delete for Everyone',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await ctrl.deleteForEveryone(message);
                            }
                          }
                        : null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAttachmentPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text('Share in Trade Chat',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // Option 1: Quotation
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2FE),
                    child: Icon(Icons.request_quote_rounded, color: Colors.blueAccent),
                  ),
                  title: const Text('Business Quotation & Catalog', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Select items, customize rates, and send price estimate'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showMultiItemQuotationDialog(context);
                  },
                ),

                // Option 2: Purchase Order
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEDE9FE),
                    child: Icon(Icons.shopping_cart_checkout_rounded, color: Colors.purple),
                  ),
                  title: const Text('Create & Send Purchase Order', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Place an official order with quantities and dispatch terms'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showCreateOrderDialog(context);
                  },
                ),

                // Option 3: PDF Document
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEE2E2),
                    child: Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
                  ),
                  title: const Text('Upload Document / PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Share product catalogs, specs, invoices, or agreements'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handlePickAndSendPdf(context);
                  },
                ),

                // Option 4: Photo / Image
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFDCFCE7),
                    child: Icon(Icons.image_rounded, color: Colors.green),
                  ),
                  title: const Text('Send Photo / Image', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Share product pictures, proofs, or barcode snapshots'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handlePickAndSendImage(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handlePickAndSendPdf(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileName = file.name;
        final fileSizeKb = (file.size / 1024).toStringAsFixed(1);
        final sizeStr = file.size > 1024 * 1024
            ? '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'
            : '$fileSizeKb KB';

        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        final base64Data = bytes != null ? base64Encode(bytes) : '';

        final attachment = ChatAttachment(
          type: 'PDF',
          id: 'pdf_${DateTime.now().millisecondsSinceEpoch}',
          title: fileName,
          subtitle: '$sizeStr • PDF Document',
          imageUrl: base64Data,
          metadata: {
            'file_name': fileName,
            'file_size': sizeStr,
            'base64': base64Data,
            'file_path': file.path,
          },
        );

        await _handleSend(
          content: '📄 Document: $fileName ($sizeStr)',
          attachment: attachment,
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to pick PDF: $e')),
        );
      }
    }
  }

  Future<void> _handlePickAndSendImage(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileName = file.name;
        final fileSizeKb = (file.size / 1024).toStringAsFixed(1);
        final sizeStr = file.size > 1024 * 1024
            ? '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'
            : '$fileSizeKb KB';

        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        final base64Data = bytes != null ? base64Encode(bytes) : '';

        final attachment = ChatAttachment(
          type: 'IMAGE',
          id: 'img_${DateTime.now().millisecondsSinceEpoch}',
          title: fileName,
          subtitle: '$sizeStr • Image',
          imageUrl: base64Data,
          metadata: {
            'file_name': fileName,
            'file_size': sizeStr,
            'base64': base64Data,
            'file_path': file.path,
          },
        );

        await _handleSend(
          content: '🖼️ Photo: $fileName',
          attachment: attachment,
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to pick Image: $e')),
        );
      }
    }
  }

  Future<void> _downloadOrOpenPdf(String fileName, String? base64Str, String? filePath) async {
    try {
      if (filePath != null && File(filePath).existsSync()) {
        await OpenFile.open(filePath);
        return;
      }

      if (base64Str != null && base64Str.isNotEmpty) {
        final bytes = base64Decode(base64Str.replaceAll(RegExp(r'\s+'), ''));
        final dir = await getTemporaryDirectory();
        final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final targetFile = File('${dir.path}/$safeName');
        await targetFile.writeAsBytes(bytes, flush: true);
        await OpenFile.open(targetFile.path);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document data is unavailable.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open PDF: $e')),
      );
    }
  }

  void _showFullImageViewer(BuildContext context, String title, String? base64Str, String? filePath) {
    Uint8List? imageBytes;
    if (base64Str != null && base64Str.isNotEmpty) {
      try {
        final cleanBase64 = base64Str.contains(',') ? base64Str.split(',').last : base64Str;
        imageBytes = base64Decode(cleanBase64.replaceAll(RegExp(r'\s+'), ''));
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (dCtx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: imageBytes != null
                  ? Image.memory(imageBytes, fit: BoxFit.contain)
                  : (filePath != null && File(filePath).existsSync()
                      ? Image.file(File(filePath), fit: BoxFit.contain)
                      : const Center(
                          child: Icon(Icons.broken_image, size: 64, color: Colors.white70),
                        )),
            ),
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(dCtx),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAndDownloadDocumentPdf({
    required String docType,
    required String docNo,
    required String senderName,
    required String senderGstin,
    required String senderCity,
    required String senderPhone,
    required String receiverName,
    required String receiverGstin,
    required String receiverCity,
    required List<dynamic> items,
    required double subtotal,
    required double taxAmount,
    required double grandTotal,
    required String notes,
  }) async {
    try {
      final pdf = pw.Document();
      final isPO = docType.toUpperCase().contains('ORDER') || docType.toUpperCase().contains('PO');
      final titleHeader = isPO ? 'PURCHASE ORDER' : 'COMMERCIAL QUOTATION';
      final primaryColor = isPO ? PdfColors.indigo900 : PdfColors.blue900;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context pCtx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Top Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          titleHeader,
                          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryColor),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text('Ref No: $docNo', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text(
                        'Total: ${CurrencyService.symbol}${grandTotal.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ),
                  ],
                ),
                pw.Divider(thickness: 1.5, color: primaryColor),
                pw.SizedBox(height: 8),

                // Parties Info
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey50,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColors.grey300),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('FROM:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                            pw.SizedBox(height: 2),
                            pw.Text(senderName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                            if (senderGstin.isNotEmpty) pw.Text('Tax ID / GSTIN: $senderGstin', style: const pw.TextStyle(fontSize: 9)),
                            if (senderCity.isNotEmpty) pw.Text('Location: $senderCity', style: const pw.TextStyle(fontSize: 9)),
                            if (senderPhone.isNotEmpty) pw.Text('Phone: $senderPhone', style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey50,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColors.grey300),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('TO / VENDOR:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                            pw.SizedBox(height: 2),
                            pw.Text(receiverName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                            if (receiverGstin.isNotEmpty) pw.Text('Tax ID / GSTIN: $receiverGstin', style: const pw.TextStyle(fontSize: 9)),
                            if (receiverCity.isNotEmpty) pw.Text('Location: $receiverCity', style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),

                // Table Header
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Row(
                    children: [
                      pw.SizedBox(width: 24, child: pw.Text('#', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.Expanded(child: pw.Text('Item Description', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.SizedBox(width: 50, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.SizedBox(width: 70, child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.SizedBox(width: 50, child: pw.Text('Tax %', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                      pw.SizedBox(width: 80, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    ],
                  ),
                ),
                pw.SizedBox(height: 4),

                // Table Rows
                ...items.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final it = entry.value;
                  final name = it['item_name']?.toString() ?? 'Item';
                  final code = it['item_code']?.toString() ?? '';
                  final unit = it['unit']?.toString() ?? 'pcs';
                  final rate = double.tryParse(it['rate']?.toString() ?? '0') ?? 0.0;
                  final qty = int.tryParse(it['quantity']?.toString() ?? '1') ?? 1;
                  final taxPercent = double.tryParse(it['tax_percent']?.toString() ?? '0') ?? 0.0;
                  final lineTotal = it['total'] != null
                      ? (double.tryParse(it['total'].toString()) ?? (rate * qty))
                      : (rate * qty);

                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: pw.BoxDecoration(
                      color: idx.isEven ? PdfColors.grey100 : PdfColors.white,
                      border: const pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
                    ),
                    child: pw.Row(
                      children: [
                        pw.SizedBox(width: 24, child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 8.5))),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(name, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              if (code.isNotEmpty) pw.Text('Code: $code', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 50, child: pw.Text('$qty $unit', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5))),
                        pw.SizedBox(width: 70, child: pw.Text('${CurrencyService.symbol}${rate.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                        pw.SizedBox(width: 50, child: pw.Text('${taxPercent.toStringAsFixed(0)}%', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8.5))),
                        pw.SizedBox(width: 80, child: pw.Text('${CurrencyService.symbol}${lineTotal.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                  );
                }),

                pw.SizedBox(height: 12),
                pw.Divider(color: PdfColors.grey400),

                // Financial Summary
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 220,
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Subtotal (Base):', style: const pw.TextStyle(fontSize: 9)),
                              pw.Text('${CurrencyService.symbol}${subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                            ],
                          ),
                          pw.SizedBox(height: 3),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Total Tax:', style: const pw.TextStyle(fontSize: 9)),
                              pw.Text('+${CurrencyService.symbol}${taxAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                            ],
                          ),
                          pw.Divider(thickness: 1, color: primaryColor),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                              pw.Text('${CurrencyService.symbol}${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (notes.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.amber50,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: PdfColors.amber200),
                    ),
                    child: pw.Text('Notes / Terms: $notes', style: const pw.TextStyle(fontSize: 8.5)),
                  ),
                ],

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Center(
                  child: pw.Text('Generated electronically via RetailSale B2B Trade Network', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        name: '${docType}_$docNo',
        onLayout: (format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  void _showCreateOrderDialog(BuildContext context) {
    final allItems = _itemCtrl.list;
    final Map<int, int> selectedQtyMap = {};
    final Map<int, double> customRateMap = {};
    final TextEditingController searchCtrl = TextEditingController();
    final TextEditingController notesCtrl = TextEditingController();
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (stCtx, setDialogState) {
            final filteredItems = allItems.where((it) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return it.itemName.toLowerCase().contains(q) ||
                  it.itemCode.toLowerCase().contains(q) ||
                  it.brand.toLowerCase().contains(q);
            }).toList();

            int totalSelectedItems = 0;
            int totalQuantity = 0;
            double subtotalAmount = 0.0;
            double totalTaxAmount = 0.0;
            double grandTotalAmount = 0.0;

            for (var it in allItems) {
              final qty = selectedQtyMap[it.id] ?? 0;
              if (qty > 0) {
                totalSelectedItems++;
                totalQuantity += qty;

                final unitRate = customRateMap[it.id] ?? (it.rate > 0 ? it.rate : (it.retailSalePrice > 0 ? it.retailSalePrice : it.mrp));
                final lineBase = unitRate * qty;
                final taxPercent = it.taxPercent > 0 ? it.taxPercent : (it.taxGroup != null ? it.taxGroup!.totalRate : 0.0);
                final lineTax = (lineBase * taxPercent) / 100.0;

                subtotalAmount += lineBase;
                totalTaxAmount += lineTax;
                grandTotalAmount += (lineBase + lineTax);
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 640,
                height: 700,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Modal Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.purple, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create & Send Purchase Order',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Select items to order, adjust quantities, custom rates & terms',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search and Action Bar
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Search items to order by name, code, brand...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        searchCtrl.clear();
                                        setDialogState(() => searchQuery = '');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onChanged: (val) => setDialogState(() => searchQuery = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Product List with Quantities, Editable Rates, and Tax %
                    Expanded(
                      child: filteredItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  Text(
                                    searchQuery.isEmpty ? 'No products in inventory.' : 'No products match "$searchQuery"',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredItems.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final it = filteredItems[i];
                                final qty = selectedQtyMap[it.id] ?? 0;
                                final isSelected = qty > 0;
                                final unitRate = customRateMap[it.id] ?? (it.rate > 0 ? it.rate : (it.retailSalePrice > 0 ? it.retailSalePrice : it.mrp));
                                final taxPercent = it.taxPercent > 0 ? it.taxPercent : (it.taxGroup != null ? it.taxGroup!.totalRate : 0.0);
                                final lineBase = unitRate * (isSelected ? qty : 1);
                                final lineTax = (lineBase * taxPercent) / 100.0;
                                final lineNet = lineBase + lineTax;

                                return Container(
                                  color: isSelected ? Colors.purple.shade50.withValues(alpha: 0.5) : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Row(
                                    children: [
                                      // Checkbox
                                      Checkbox(
                                        value: isSelected,
                                        activeColor: Colors.purple.shade800,
                                        onChanged: (val) {
                                          setDialogState(() {
                                            if (val == true) {
                                              selectedQtyMap[it.id] = 1;
                                            } else {
                                              selectedQtyMap.remove(it.id);
                                            }
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 4),

                                      // Item Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              it.itemName,
                                              style: TextStyle(
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  '${it.itemCode} • ${it.brand} (${it.unit})',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                ),
                                                if (taxPercent > 0) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.purple.shade50,
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.purple.shade200),
                                                    ),
                                                    child: Text(
                                                      'Tax: ${taxPercent.toStringAsFixed(0)}%',
                                                      style: TextStyle(fontSize: 9.5, color: Colors.purple.shade800, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Editable Purchase Rate
                                      InkWell(
                                        onTap: () async {
                                          final editCtrl = TextEditingController(text: unitRate.toStringAsFixed(2));
                                          final newPrice = await showDialog<double>(
                                            context: dialogCtx,
                                            builder: (eCtx) => AlertDialog(
                                              title: Text('Edit Purchase Rate: ${it.itemName}'),
                                              content: TextField(
                                                controller: editCtrl,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                autofocus: true,
                                                decoration: InputDecoration(
                                                  labelText: 'Purchase Rate (Tax Exclusive)',
                                                  prefixText: '${CurrencyService.symbol} ',
                                                  border: const OutlineInputBorder(),
                                                ),
                                              ),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(eCtx), child: const Text('Cancel')),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    final p = double.tryParse(editCtrl.text.trim());
                                                    Navigator.pop(eCtx, p);
                                                  },
                                                  child: const Text('Apply Rate'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (newPrice != null && newPrice >= 0) {
                                            setDialogState(() {
                                              customRateMap[it.id] = newPrice;
                                              if (qty == 0) selectedQtyMap[it.id] = 1;
                                            });
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.purple.shade200),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                CurrencyService.format(unitRate),
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple.shade900),
                                              ),
                                              const SizedBox(width: 3),
                                              Icon(Icons.edit, size: 12, color: Colors.purple.shade900),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Quantity Adjuster
                                      if (isSelected) ...[
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.purple.shade200),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: () {
                                                  setDialogState(() {
                                                    if (qty > 1) {
                                                      selectedQtyMap[it.id] = qty - 1;
                                                    } else {
                                                      selectedQtyMap.remove(it.id);
                                                    }
                                                  });
                                                },
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  child: Icon(Icons.remove, size: 16, color: Colors.red),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                child: Text(
                                                  '$qty',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  setDialogState(() {
                                                    selectedQtyMap[it.id] = qty + 1;
                                                  });
                                                },
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  child: Icon(Icons.add, size: 16, color: Colors.green),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 80,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                CurrencyService.format(lineNet),
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: Colors.black87),
                                              ),
                                              if (taxPercent > 0)
                                                Text(
                                                  'Tax: +${CurrencyService.format(lineTax)}',
                                                  style: TextStyle(fontSize: 9.5, color: Colors.purple.shade700),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ] else ...[
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            minimumSize: const Size(60, 30),
                                          ),
                                          onPressed: () {
                                            setDialogState(() => selectedQtyMap[it.id] = 1);
                                          },
                                          child: const Text('Add', style: TextStyle(fontSize: 11)),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),

                    // Order Notes / Delivery terms
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        hintText: 'Order Instructions / Delivery Terms (e.g. Deliver to main warehouse within 48h)',
                        prefixIcon: const Icon(Icons.local_shipping_outlined, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Summary Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Selected Items:', style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                              Text('$totalSelectedItems products ($totalQuantity units)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal (Base):', style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                              Text(CurrencyService.format(subtotalAmount),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Estimated Tax:', style: TextStyle(fontSize: 12, color: Colors.purple.shade700)),
                              Text('+${CurrencyService.format(totalTaxAmount)}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade800)),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Grand Total (Tax Included):',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                              Text(
                                CurrencyService.format(grandTotalAmount),
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.purple.shade900),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            totalSelectedItems > 0
                                ? 'Send Purchase Order (${CurrencyService.format(grandTotalAmount)})'
                                : 'Select Items to Order',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: totalSelectedItems == 0
                              ? null
                              : () {
                                  Navigator.pop(dialogCtx);

                                  final List<Map<String, dynamic>> orderItems = [];
                                  for (var it in allItems) {
                                    final qty = selectedQtyMap[it.id] ?? 0;
                                    if (qty > 0) {
                                      final unitRate = customRateMap[it.id] ?? (it.rate > 0 ? it.rate : (it.retailSalePrice > 0 ? it.retailSalePrice : it.mrp));
                                      final taxPercent = it.taxPercent > 0 ? it.taxPercent : (it.taxGroup != null ? it.taxGroup!.totalRate : 0.0);
                                      final lineBase = unitRate * qty;
                                      final lineTax = (lineBase * taxPercent) / 100.0;
                                      final lineNet = lineBase + lineTax;

                                      orderItems.add({
                                        'item_id': it.id,
                                        'item_name': it.itemName,
                                        'item_code': it.itemCode,
                                        'brand': it.brand,
                                        'unit': it.unit,
                                        'rate': unitRate,
                                        'quantity': qty,
                                        'tax_percent': taxPercent,
                                        'tax_amount': lineTax,
                                        'base_amount': lineBase,
                                        'total': lineNet,
                                      });
                                    }
                                  }

                                  final poNo = 'PO-${DateTime.now().millisecondsSinceEpoch % 100000}';
                                  final noteText = notesCtrl.text.trim();

                                  final attachment = ChatAttachment(
                                    type: 'PURCHASE_ORDER',
                                    id: 'po_${DateTime.now().millisecondsSinceEpoch}',
                                    title: 'Purchase Order $poNo ($totalSelectedItems Items)',
                                    subtitle: 'Net: ${CurrencyService.format(grandTotalAmount)} • $totalQuantity Units',
                                    price: grandTotalAmount,
                                    metadata: {
                                      'po_no': poNo,
                                      'total_items': totalSelectedItems,
                                      'total_qty': totalQuantity,
                                      'subtotal': subtotalAmount,
                                      'tax_amount': totalTaxAmount,
                                      'grand_total': grandTotalAmount,
                                      'notes': noteText,
                                      'items': orderItems,
                                      'status': 'PLACED',
                                    },
                                  );

                                  _handleSend(
                                    content: noteText.isNotEmpty
                                        ? '🛒 Purchase Order $poNo: $noteText'
                                        : '🛒 Official Purchase Order $poNo ($totalSelectedItems Items)',
                                    attachment: attachment,
                                  );
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveAsVendorMaster({
    required String merchantName,
    required String taxId,
    required String phone,
    required String city,
    required String state,
  }) async {
    try {
      final supplierCtrl = context.read<SupplierController>();
      await supplierCtrl.load();

      final cleanName = merchantName.trim().toLowerCase();
      final cleanTax = taxId.trim().toLowerCase();

      final exists = supplierCtrl.list.any((s) =>
          (cleanName.isNotEmpty && s.supplierName.trim().toLowerCase() == cleanName) ||
          (cleanTax.isNotEmpty && cleanTax != 'registered' && cleanTax != 'tax id' &&
              (s.taxIdNumber?.trim().toLowerCase() == cleanTax || s.gstin?.trim().toLowerCase() == cleanTax)));

      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ $merchantName is already registered in your Vendor Master.')),
          );
        }
        return;
      }

      final nextCode = await supplierCtrl.getNextCode();
      final newSupplier = Supplier(
        id: 0,
        supplierCode: nextCode,
        supplierName: merchantName,
        address: city.isNotEmpty ? city : 'Registered Address',
        phone: phone,
        state: state.isNotEmpty ? state : city,
        gstin: taxId.isNotEmpty && taxId.toLowerCase() != 'registered' ? taxId : '',
        taxIdNumber: taxId.isNotEmpty && taxId.toLowerCase() != 'registered' ? taxId : '',
        isActive: true,
      );

      await supplierCtrl.create(newSupplier);
      await supplierCtrl.load();

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF15803D),
            content: Text('✅ Successfully saved $merchantName to Vendor Master (Code: $nextCode)!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save vendor: $e')),
        );
      }
    }
  }

  void _showMerchantProfileModal(BuildContext context, ChatMessage msg, CommunityController ctrl) {
    final supplierCtrl = context.read<SupplierController>();
    final isSaved = _isMerchantInVendorMaster(
      supplierCtrl,
      name: msg.senderName,
      taxId: msg.senderGstin,
      phone: msg.senderPhone,
      merchantId: msg.senderId,
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Merchant Header Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : 'M',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.senderName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (msg.senderGstin.isNotEmpty)
                            Text('Tax ID: ${msg.senderGstin}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          Text(
                            msg.senderCity.isNotEmpty && msg.senderPhone.isNotEmpty
                                ? '${msg.senderCity} • ${msg.senderPhone}'
                                : (msg.senderCity.isNotEmpty ? msg.senderCity : msg.senderPhone),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                // 1. Direct B2B Chat Action
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF1E40AF)),
                  title: Text('Start B2B Direct Chat with ${msg.senderName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Open 1-on-1 private trade chat'),
                  onTap: () {
                    Navigator.pop(ctx);
                    final directChat = ctrl.getOrCreateDirectChat(
                      recipientId: msg.senderId,
                      recipientName: msg.senderName,
                      recipientGstin: msg.senderGstin,
                      recipientPhone: msg.senderPhone,
                      recipientCity: msg.senderCity,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatConversationScreen(conversation: directChat),
                      ),
                    );
                  },
                ),
                // 2. Save to Vendor Master Action
                if (!isSaved)
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1, color: Colors.green),
                    title: Text('Save ${msg.senderName} to Vendor Master', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Save contact & tax info into supplier directory'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _saveAsVendorMaster(
                        merchantName: msg.senderName,
                        taxId: msg.senderGstin,
                        phone: msg.senderPhone,
                        city: msg.senderCity,
                        state: msg.senderCity,
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMultiItemQuotationDialog(BuildContext context) {
    final allItems = _itemCtrl.list;
    final Map<int, int> selectedQtyMap = {}; // itemId -> quantity
    final Map<int, double> customRateMap = {}; // itemId -> editable custom rate
    final searchCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final cleanQ = searchQuery.toLowerCase().trim();
            final filteredItems = allItems.where((it) {
              if (cleanQ.isEmpty) return true;
              return it.itemName.toLowerCase().contains(cleanQ) ||
                  it.itemCode.toLowerCase().contains(cleanQ) ||
                  it.brand.toLowerCase().contains(cleanQ) ||
                  it.itemGroup.toLowerCase().contains(cleanQ);
            }).toList();

            // Calculate totals with item-wise tax %
            int totalSelectedItems = 0;
            int totalQuantity = 0;
            double subtotalAmount = 0.0;
            double totalTaxAmount = 0.0;
            double grandTotalAmount = 0.0;

            for (var it in allItems) {
              final qty = selectedQtyMap[it.id] ?? 0;
              if (qty > 0) {
                totalSelectedItems++;
                totalQuantity += qty;

                final unitRate = customRateMap[it.id] ?? (it.retailSalePrice > 0 ? it.retailSalePrice : it.rate);
                final lineBase = unitRate * qty;
                final taxPercent = it.taxPercent > 0 ? it.taxPercent : (it.taxGroup != null ? it.taxGroup!.totalRate : 0.0);
                final lineTax = (lineBase * taxPercent) / 100.0;

                subtotalAmount += lineBase;
                totalTaxAmount += lineTax;
                grandTotalAmount += (lineBase + lineTax);
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 640,
                height: 700,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Modal Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.request_quote_rounded, color: Color(0xFF1E40AF), size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create & Send Commercial Quotation',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Select products, adjust rates & quantities, calculate tax & send estimate',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search and Action Bar
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Search products by name, code, brand...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        searchCtrl.clear();
                                        setDialogState(() => searchQuery = '');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onChanged: (val) => setDialogState(() => searchQuery = val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (filteredItems.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                final allFilteredSelected = filteredItems.every((it) => (selectedQtyMap[it.id] ?? 0) > 0);
                                for (var it in filteredItems) {
                                  if (allFilteredSelected) {
                                    selectedQtyMap.remove(it.id);
                                  } else {
                                    selectedQtyMap[it.id] = selectedQtyMap[it.id] ?? 1;
                                  }
                                }
                              });
                            },
                            child: Text(
                              filteredItems.every((it) => (selectedQtyMap[it.id] ?? 0) > 0)
                                  ? 'Deselect All'
                                  : 'Select All (${filteredItems.length})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Product List with Quantities, Editable Rates, and Tax %
                    Expanded(
                      child: filteredItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  Text(
                                    searchQuery.isEmpty ? 'No products in inventory.' : 'No products match "$searchQuery"',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredItems.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final it = filteredItems[i];
                                final qty = selectedQtyMap[it.id] ?? 0;
                                final isSelected = qty > 0;
                                final unitRate = customRateMap[it.id] ?? (it.retailSalePrice > 0 ? it.retailSalePrice : it.rate);
                                final taxPercent = it.taxPercent > 0 ? it.taxPercent : (it.taxGroup != null ? it.taxGroup!.totalRate : 0.0);
                                final lineBase = unitRate * (isSelected ? qty : 1);
                                final lineTax = (lineBase * taxPercent) / 100.0;
                                final lineNet = lineBase + lineTax;

                                return Container(
                                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Row(
                                    children: [
                                      // Checkbox
                                      Checkbox(
                                        value: isSelected,
                                        activeColor: const Color(0xFF1E40AF),
                                        onChanged: (val) {
                                          setDialogState(() {
                                            if (val == true) {
                                              selectedQtyMap[it.id] = 1;
                                            } else {
                                              selectedQtyMap.remove(it.id);
                                            }
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 4),

                                      // Item Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              it.itemName,
                                              style: TextStyle(
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  '${it.itemCode} • ${it.brand} (${it.unit})',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                ),
                                                if (taxPercent > 0) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.purple.shade50,
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.purple.shade200),
                                                    ),
                                                    child: Text(
                                                      'Tax: ${taxPercent.toStringAsFixed(0)}%',
                                                      style: TextStyle(fontSize: 9.5, color: Colors.purple.shade800, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Editable Rate Box
                                      InkWell(
                                        onTap: () async {
                                          final editCtrl = TextEditingController(text: unitRate.toStringAsFixed(2));
                                          final newPrice = await showDialog<double>(
                                            context: dialogCtx,
                                            builder: (eCtx) => AlertDialog(
                                              title: Text('Edit Rate: ${it.itemName}'),
                                              content: TextField(
                                                controller: editCtrl,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                autofocus: true,
                                                decoration: const InputDecoration(
                                                  labelText: 'Custom Unit Rate (Tax Exclusive)',
                                                  prefixText: '₹ ',
                                                  border: OutlineInputBorder(),
                                                ),
                                              ),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(eCtx), child: const Text('Cancel')),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    final p = double.tryParse(editCtrl.text.trim());
                                                    Navigator.pop(eCtx, p);
                                                  },
                                                  child: const Text('Apply Rate'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (newPrice != null && newPrice >= 0) {
                                            setDialogState(() {
                                              customRateMap[it.id] = newPrice;
                                              if (qty == 0) selectedQtyMap[it.id] = 1;
                                            });
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.blue.shade200),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                CurrencyService.format(unitRate),
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E40AF)),
                                              ),
                                              const SizedBox(width: 3),
                                              const Icon(Icons.edit, size: 12, color: Color(0xFF1E40AF)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Quantity Adjuster (shown when selected)
                                      if (isSelected) ...[
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.blue.shade200),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: () {
                                                  setDialogState(() {
                                                    if (qty > 1) {
                                                      selectedQtyMap[it.id] = qty - 1;
                                                    } else {
                                                      selectedQtyMap.remove(it.id);
                                                    }
                                                  });
                                                },
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  child: Icon(Icons.remove, size: 16, color: Colors.red),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                child: Text(
                                                  '$qty',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  setDialogState(() {
                                                    selectedQtyMap[it.id] = qty + 1;
                                                  });
                                                },
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  child: Icon(Icons.add, size: 16, color: Colors.green),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 80,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                CurrencyService.format(lineNet),
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: Colors.black87),
                                              ),
                                              if (taxPercent > 0)
                                                Text(
                                                  'Tax: +${CurrencyService.format(lineTax)}',
                                                  style: TextStyle(fontSize: 9.5, color: Colors.purple.shade700),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ] else ...[
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            minimumSize: const Size(60, 30),
                                          ),
                                          onPressed: () {
                                            setDialogState(() => selectedQtyMap[it.id] = 1);
                                          },
                                          child: const Text('Add', style: TextStyle(fontSize: 11)),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),

                    // Quotation Note Input
                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        hintText: 'Quotation Note / Terms (e.g. Validity: 7 days, Delivery within 24h)',
                        prefixIcon: const Icon(Icons.edit_note, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Calculation Summary Bar with Subtotal, Tax Amount, and Net Total
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected: $totalSelectedItems Products ($totalQuantity Qty)',
                                style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Subtotal: ${CurrencyService.format(subtotalAmount)}  •  Tax: ${CurrencyService.format(totalTaxAmount)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'NET TOTAL (INCL. TAX)',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                              Text(
                                CurrencyService.format(grandTotalAmount),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E40AF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            totalSelectedItems > 0
                                ? 'Send Quotation (${CurrencyService.format(grandTotalAmount)})'
                                : 'Select Products to Send',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: totalSelectedItems == 0
                              ? null
                              : () {
                                  Navigator.pop(dialogCtx);

                                  // Build structured quotation items list
                                  final List<Map<String, dynamic>> quotationItems = [];
                                  for (var it in allItems) {
                                    final qty = selectedQtyMap[it.id] ?? 0;
                                    if (qty > 0) {
                                      final unitRate = customRateMap[it.id] ?? (it.retailSalePrice > 0 ? it.retailSalePrice : it.rate);
                                      final taxPercent = it.taxPercent > 0 ? it.taxPercent : (it.taxGroup != null ? it.taxGroup!.totalRate : 0.0);
                                      final lineBase = unitRate * qty;
                                      final lineTax = (lineBase * taxPercent) / 100.0;
                                      final lineNet = lineBase + lineTax;

                                      quotationItems.add({
                                        'item_id': it.id,
                                        'item_name': it.itemName,
                                        'item_code': it.itemCode,
                                        'brand': it.brand,
                                        'unit': it.unit,
                                        'rate': unitRate,
                                        'quantity': qty,
                                        'tax_percent': taxPercent,
                                        'tax_amount': lineTax,
                                        'base_amount': lineBase,
                                        'total': lineNet,
                                      });
                                    }
                                  }

                                  final quoteNo = 'QT-${DateTime.now().millisecondsSinceEpoch % 100000}';
                                  final noteText = notesCtrl.text.trim();

                                  final attachment = ChatAttachment(
                                    type: 'QUOTATION',
                                    id: 'quote_${DateTime.now().millisecondsSinceEpoch}',
                                    title: 'Quotation $quoteNo ($totalSelectedItems Items)',
                                    subtitle: 'Net: ${CurrencyService.format(grandTotalAmount)} • $totalQuantity Units',
                                    price: grandTotalAmount,
                                    metadata: {
                                      'quotation_no': quoteNo,
                                      'total_items': totalSelectedItems,
                                      'total_qty': totalQuantity,
                                      'subtotal': subtotalAmount,
                                      'tax_amount': totalTaxAmount,
                                      'grand_total': grandTotalAmount,
                                      'notes': noteText,
                                      'items': quotationItems,
                                    },
                                  );

                                  _handleSend(
                                    content: noteText.isNotEmpty
                                        ? '📋 Quotation $quoteNo: $noteText'
                                        : '📋 Business Quotation $quoteNo ($totalSelectedItems Items)',
                                    attachment: attachment,
                                  );
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  @override

  Widget build(BuildContext context) {
    final ctrl = context.watch<CommunityController>();
    final supplierCtrl = context.watch<SupplierController>();
    final messages = ctrl.getMessages(widget.conversation.id);
    final theme = Theme.of(context);

    // Identify counterpart merchant ID for direct chat
    final counterpartId = widget.conversation.isDirect
        ? (widget.conversation.creatorMerchantId == ctrl.currentMerchantId
            ? widget.conversation.directRecipientId
            : widget.conversation.creatorMerchantId)
        : null;
    final isCounterpartBlocked = counterpartId != null && ctrl.isBlocked(counterpartId);
    final isConversationMuted = ctrl.isMuted(widget.conversation.id);

    final counterpartName = widget.conversation.getDisplayTitle(ctrl.currentMerchantId, ctrl.currentMerchantName);
    final counterpartTaxId = widget.conversation.getDisplayGstin(ctrl.currentMerchantId, ctrl.currentProperty?.gstNo);
    final isAlreadySavedAsVendor = widget.conversation.isDirect && _isMerchantInVendorMaster(
      supplierCtrl,
      name: counterpartName,
      taxId: counterpartTaxId,
      phone: widget.conversation.directRecipientPhone,
      merchantId: counterpartId,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: widget.conversation.isDirect
                  ? Colors.blue.shade100
                  : Colors.purple.shade100,
              child: Icon(
                widget.conversation.isDirect ? Icons.store : Icons.tag,
                size: 20,
                color: widget.conversation.isDirect
                    ? Colors.blue.shade800
                    : Colors.purple.shade800,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.conversation.getDisplayTitle(ctrl.currentMerchantId, ctrl.currentMerchantName),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isConversationMuted) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.volume_off_rounded, size: 15, color: Colors.grey),
                      ],
                    ],
                  ),
                  Text(
                    widget.conversation.isDirect
                        ? 'Tax ID: ${widget.conversation.getDisplayGstin(ctrl.currentMerchantId, ctrl.currentProperty?.gstNo)} • ${widget.conversation.regionCity}'
                        : '${widget.conversation.regionCity} Regional Trade Network',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              if (val == 'save_vendor') {
                final displayTitle = widget.conversation.getDisplayTitle(ctrl.currentMerchantId, ctrl.currentMerchantName);
                final counterpartTaxId = widget.conversation.getDisplayGstin(ctrl.currentMerchantId, ctrl.currentProperty?.gstNo);
                await _saveAsVendorMaster(
                  merchantName: displayTitle,
                  taxId: counterpartTaxId != 'Registered' ? counterpartTaxId : '',
                  phone: widget.conversation.directRecipientPhone ?? '',
                  city: widget.conversation.regionCity,
                  state: widget.conversation.regionCity,
                );
              } else if (val == 'mute') {
                await ctrl.toggleMuteConversation(widget.conversation.id);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      ctrl.isMuted(widget.conversation.id)
                          ? 'Notifications muted for this conversation'
                          : 'Notifications unmuted',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              } else if (val == 'clear_chat') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Clear Chat?'),
                    content: const Text(
                        'Are you sure you want to clear all messages in this chat? Messages will be deleted from your view.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Clear Chat', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ctrl.clearChat(widget.conversation.id);
                  if (mounted) {
                    setState(() {
                      _lastMsgCount = 0;
                    });
                  }
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Chat cleared successfully')),
                  );
                }
              } else if (val == 'exit_channel') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Exit Community?'),
                    content: Text('Are you sure you want to leave ${widget.conversation.title}? You will no longer receive updates from this group.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Exit Community', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ctrl.exitChannel(widget.conversation.id);
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('You have exited the community channel')),
                  );
                }
              } else if (val == 'toggle_block') {
                if (counterpartId == null) return;
                if (isCounterpartBlocked) {
                  await ctrl.unblockMerchant(counterpartId);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Unblocked ${widget.conversation.title}')),
                  );
                } else {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Block Merchant?'),
                      content: Text('Blocked merchants cannot send you messages. Are you sure you want to block ${widget.conversation.title}?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Block', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ctrl.blockMerchant(counterpartId);
                    messenger.showSnackBar(
                      SnackBar(content: Text('Blocked ${widget.conversation.title}')),
                    );
                  }
                }
              }
            },

            itemBuilder: (ctx) => [
              if (widget.conversation.isDirect && !isAlreadySavedAsVendor)
                const PopupMenuItem(
                  value: 'save_vendor',
                  child: Row(
                    children: [
                      Icon(Icons.person_add_alt_1, size: 20, color: Colors.green),
                      SizedBox(width: 10),
                      Text('Save to Vendor Master'),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'mute',
                child: Row(
                  children: [
                    Icon(
                      isConversationMuted ? Icons.notifications_active : Icons.notifications_off_outlined,
                      size: 20,
                      color: isConversationMuted ? Colors.blue : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 10),
                    Text(isConversationMuted ? 'Unmute Notifications' : 'Mute Notifications'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_chat',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_outlined, size: 20, color: Colors.orange.shade800),
                    const SizedBox(width: 10),
                    Text('Clear Chat', style: TextStyle(color: Colors.orange.shade900)),
                  ],
                ),
              ),
              if (!widget.conversation.isDirect)
                const PopupMenuItem(
                  value: 'exit_channel',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app, size: 20, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Exit Community', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              if (widget.conversation.isDirect && counterpartId != null)
                PopupMenuItem(
                  value: 'toggle_block',
                  child: Row(
                    children: [
                      Icon(
                        isCounterpartBlocked ? Icons.lock_open : Icons.block,
                        size: 20,
                        color: isCounterpartBlocked ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isCounterpartBlocked ? 'Unblock Merchant' : 'Block Merchant',
                        style: TextStyle(color: isCounterpartBlocked ? Colors.green : Colors.red),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Notice banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                color: Colors.amber.shade50,
                child: Row(
                  children: [
                    Icon(Icons.verified_user_outlined, size: 15, color: Colors.amber.shade900),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Verified business channel. Delete for everyone & edit are available within 1 hour.',
                        style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),

              // Messages List
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_outlined, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text(
                              widget.conversation.isDirect
                                  ? 'Start a private direct conversation with ${widget.conversation.title}'
                                  : 'Welcome to ${widget.conversation.title}!\nShare inventory, trade offers, and collaborate.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : Builder(
                        builder: (ctx) {
                          if (messages.length != _lastMsgCount) {
                            _lastMsgCount = messages.length;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_scrollCtrl.hasClients) {
                                _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                              }
                            });
                          }
                          return ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              final isMe = _isMessageFromMe(msg, ctrl);
                              return _buildMessageBubble(context, msg, isMe, ctrl);
                            },
                          );
                        },
                      ),
              ),

              // Input Bar or Blocked Notice
              if (isCounterpartBlocked)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      const Icon(Icons.block, color: Colors.red, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'You have blocked this merchant.',
                          style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () async {
                          await ctrl.unblockMerchant(counterpartId);
                        },
                        child: const Text('Unblock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                )
              else
                _buildInputBar(theme),
            ],
          ),


          // Real @Mention Autocomplete Popup
          if (_showMentionPopup && _mentionSuggestions.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 70,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _mentionSuggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final m = _mentionSuggestions[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            m.businessName.isNotEmpty ? m.businessName[0].toUpperCase() : 'M',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text('@${m.handle}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 13)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                m.businessName,
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${m.city} • ${m.gstin.isNotEmpty ? m.gstin : "Verified Merchant"}',
                          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                        ),
                        onTap: () => _applyMention(m),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage msg, bool isMe, CommunityController ctrl) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('hh:mm a').format(msg.createdAt.toLocal());

    // Dynamic Tax ID / GSTIN
    final senderGst = isMe
        ? ctrl.currentGstin
        : (msg.senderGstin.isNotEmpty ? msg.senderGstin : (ctrl.currentMerchantId == '2' ? 'GSTIN' : 'GSTIN45454544'));

    return Align(
      // WhatsApp style: SENDER (Me) on the RIGHT, RECEIVER (Other party) on the LEFT
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActionSheet(context, msg),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            // WhatsApp green (#D9FDD3) for sender on the right, clean white for receiver on the left
            color: msg.isDeletedForEveryone
                ? const Color(0xFFF1F5F9)
                : (isMe ? const Color(0xFFD9FDD3) : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isMe ? 12 : 2),
              bottomRight: Radius.circular(isMe ? 2 : 12),
            ),
            border: Border.all(
              color: msg.isDeletedForEveryone
                  ? Colors.grey.shade300
                  : (isMe ? const Color(0xFFB4E39E).withValues(alpha: 0.8) : const Color(0xFFE2E8F0)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isMe ? 0.02 : 0.05),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Sender / Receiver Identity Header with Name and Tax ID (GSTIN)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMe) ...[
                      // Receiver / Other Merchant Header (Clickable like WhatsApp to open private direct chat or save contact)
                      InkWell(
                        onTap: () => _showMerchantProfileModal(context, msg, ctrl),
                        borderRadius: BorderRadius.circular(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msg.senderName.isNotEmpty ? msg.senderName : 'Business Partner',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                            if (senderGst.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Text(
                                  'Tax ID: $senderGst',
                                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            if (msg.senderCity.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '• ${msg.senderCity}',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      // Sender (Me) Header
                      if (senderGst.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Text(
                            'Tax ID: $senderGst',
                            style: const TextStyle(fontSize: 9, color: Color(0xFF15803D), fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      const Text(
                        'You',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Attachment Card (Quotation / Multi-Item Catalog or Single Product)
              if (msg.attachment != null && !msg.isDeletedForEveryone) ...[
                _buildAttachmentCard(context, msg, isMe),
              ],


              // Message Body with @mention rich styling
              _buildRichMentionText(msg.content, msg.isDeletedForEveryone, isMe, theme),
              const SizedBox(height: 3),

              // Timestamp & Status (WhatsApp style)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? const Color(0xFF4B5563) : const Color(0xFF6B7280),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.done_all, size: 14, color: Color(0xFF0284C7)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentCard(BuildContext context, ChatMessage msg, bool isMe) {
    final attachment = msg.attachment!;
    final metadata = attachment.metadata;
    final type = attachment.type.toUpperCase();

    // 1. PDF Document Card (WhatsApp Style)
    if (type == 'PDF' || (metadata != null && metadata['file_name']?.toString().toLowerCase().endsWith('.pdf') == true)) {
      final fileName = metadata?['file_name']?.toString() ?? attachment.title;
      final fileSize = metadata?['file_size']?.toString() ?? attachment.subtitle;
      final base64Data = metadata?['base64']?.toString() ?? attachment.imageUrl;
      final filePath = metadata?['file_path']?.toString();

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.95) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _downloadOrOpenPdf(fileName, base64Data, filePath),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 28),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileSize.isNotEmpty ? fileSize : 'PDF Document',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF1E40AF)),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Photo / Image Card (WhatsApp Style)
    if (type == 'IMAGE' || (metadata != null && (metadata['file_name']?.toString().toLowerCase().endsWith('.png') == true || metadata['file_name']?.toString().toLowerCase().endsWith('.jpg') == true || metadata['file_name']?.toString().toLowerCase().endsWith('.jpeg') == true))) {
      final fileName = metadata?['file_name']?.toString() ?? attachment.title;
      final base64Data = metadata?['base64']?.toString() ?? attachment.imageUrl;
      final filePath = metadata?['file_path']?.toString();

      Uint8List? imageBytes;
      if (base64Data != null && base64Data.isNotEmpty) {
        try {
          final cleanBase64 = base64Data.contains(',') ? base64Data.split(',').last : base64Data;
          imageBytes = base64Decode(cleanBase64.replaceAll(RegExp(r'\s+'), ''));
        } catch (_) {}
      }

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.95) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showFullImageViewer(context, fileName, base64Data, filePath),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(maxHeight: 220, minWidth: 200),
                width: double.infinity,
                color: Colors.black12,
                child: imageBytes != null
                    ? Image.memory(imageBytes, fit: BoxFit.cover)
                    : (filePath != null && File(filePath).existsSync()
                        ? Image.file(File(filePath), fit: BoxFit.cover)
                        : const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Icon(Icons.image, size: 48, color: Colors.grey),
                            ),
                          )),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_size_select_actual_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        fileName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

    // 3. Purchase Order Card
    final isPurchaseOrder = type == 'PURCHASE_ORDER' || type == 'ORDER';
    if (isPurchaseOrder && metadata != null && metadata['items'] is List) {
      final List<dynamic> items = metadata['items'];
      final poNo = metadata['po_no']?.toString() ?? 'PO-${attachment.id.substring(0, 6)}';
      final notes = metadata['notes']?.toString() ?? '';
      final totalQty = metadata['total_qty'] ?? items.length;
      final subtotal = metadata['subtotal'] != null ? (double.tryParse(metadata['subtotal'].toString()) ?? 0.0) : 0.0;
      final taxAmount = metadata['tax_amount'] != null ? (double.tryParse(metadata['tax_amount'].toString()) ?? 0.0) : 0.0;

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.95) : const Color(0xFFFAF5FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe ? const Color(0xFFC084FC) : const Color(0xFFA855F7),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PO Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.shopping_cart_checkout_rounded, size: 18, color: Colors.purple),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'OFFICIAL PURCHASE ORDER',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    poNo,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                  ),
                ),
              ],
            ),
            const Divider(height: 14),

            // Itemized List
            ...items.take(5).map((it) {
              final name = it['item_name']?.toString() ?? 'Item';
              final code = it['item_code']?.toString() ?? '';
              final brand = it['brand']?.toString() ?? '';
              final unit = it['unit']?.toString() ?? 'pcs';
              final rate = double.tryParse(it['rate']?.toString() ?? '0') ?? 0.0;
              final qty = int.tryParse(it['quantity']?.toString() ?? '1') ?? 1;
              final taxPercent = double.tryParse(it['tax_percent']?.toString() ?? '0') ?? 0.0;
              final lineTotal = it['total'] != null
                  ? (double.tryParse(it['total'].toString()) ?? (rate * qty))
                  : (rate * qty);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '$qty $unit x ${CurrencyService.format(rate)}${brand.isNotEmpty ? " • $brand" : ""}${code.isNotEmpty ? " ($code)" : ""}',
                                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (taxPercent > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    'Tax ${taxPercent.toStringAsFixed(0)}%',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyService.format(lineTotal),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              );
            }),

            if (items.length > 5) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '+ ${items.length - 5} more items in this order',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.purple.shade800),
                ),
              ),
            ],

            if (notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Text(
                  '🚚 $notes',
                  style: TextStyle(fontSize: 11, color: Colors.purple.shade900),
                ),
              ),
            ],

            const Divider(height: 14),

            // Financial Summary Breakdown
            if (taxAmount > 0 || subtotal > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal (Base):', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                  Text(CurrencyService.format(subtotal > 0 ? subtotal : (attachment.price - taxAmount)),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                ],
              ),
              if (taxAmount > 0) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Estimated Tax:', style: TextStyle(fontSize: 11, color: Colors.purple.shade700)),
                    Text('+${CurrencyService.format(taxAmount)}',
                        style: TextStyle(fontSize: 11, color: Colors.purple.shade800, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
              const SizedBox(height: 4),
            ],

            // Grand Total Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Total (${items.length} Items, $totalQty Qty):',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                ),
                Text(
                  CurrencyService.format(attachment.price),
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.purple.shade900),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // PO Actions
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 14, color: Colors.purple),
                      label: const Text('Download PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                      onPressed: () {
                        final ctrl = context.read<CommunityController>();
                        _generateAndDownloadDocumentPdf(
                          docType: 'Purchase_Order',
                          docNo: poNo,
                          senderName: msg.senderName,
                          senderGstin: msg.senderGstin,
                          senderCity: msg.senderCity,
                          senderPhone: msg.senderPhone,
                          receiverName: widget.conversation.getDisplayTitle(ctrl.currentMerchantId, ctrl.currentMerchantName),
                          receiverGstin: widget.conversation.getDisplayGstin(ctrl.currentMerchantId, ctrl.currentProperty?.gstNo),
                          receiverCity: widget.conversation.regionCity,
                          items: items,
                          subtotal: subtotal > 0 ? subtotal : (attachment.price - taxAmount),
                          taxAmount: taxAmount,
                          grandTotal: attachment.price,
                          notes: notes,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('Open PO Screen', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PurchaseOrderScreen(
                              supplierName: msg.senderName,
                              draftItems: items.map((i) => {
                                'item_code': i['item_code'],
                                'item_name': i['item_name'],
                                'rate': i['rate'],
                                'quantity': i['quantity'],
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 4. Commercial Quotation Card
    final isQuotation = type == 'QUOTATION' || (metadata != null && metadata['items'] != null);
    if (isQuotation && metadata != null && metadata['items'] is List) {
      final List<dynamic> items = metadata['items'];
      final quoteNo = metadata['quotation_no']?.toString() ?? 'QT-${attachment.id.substring(0, 6)}';
      final notes = metadata['notes']?.toString() ?? '';
      final totalQty = metadata['total_qty'] ?? items.length;
      final subtotal = metadata['subtotal'] != null ? (double.tryParse(metadata['subtotal'].toString()) ?? 0.0) : 0.0;
      final taxAmount = metadata['tax_amount'] != null ? (double.tryParse(metadata['tax_amount'].toString()) ?? 0.0) : 0.0;

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.95) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe ? const Color(0xFF86EFAC) : const Color(0xFF93C5FD),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quotation Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF1E40AF)),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'COMMERCIAL QUOTATION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E40AF),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    quoteNo,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
            const Divider(height: 14),

            // Itemized List (up to 5 items shown)
            ...items.take(5).map((it) {
              final name = it['item_name']?.toString() ?? 'Item';
              final code = it['item_code']?.toString() ?? '';
              final brand = it['brand']?.toString() ?? '';
              final unit = it['unit']?.toString() ?? 'pcs';
              final rate = double.tryParse(it['rate']?.toString() ?? '0') ?? 0.0;
              final qty = int.tryParse(it['quantity']?.toString() ?? '1') ?? 1;
              final taxPercent = double.tryParse(it['tax_percent']?.toString() ?? '0') ?? 0.0;
              final lineTotal = it['total'] != null
                  ? (double.tryParse(it['total'].toString()) ?? (rate * qty))
                  : (rate * qty);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '$qty $unit x ${CurrencyService.format(rate)}${brand.isNotEmpty ? " • $brand" : ""}${code.isNotEmpty ? " ($code)" : ""}',
                                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (taxPercent > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    'Tax ${taxPercent.toStringAsFixed(0)}%',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyService.format(lineTotal),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              );
            }),

            if (items.length > 5) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '+ ${items.length - 5} more items in this quotation',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blue.shade800),
                ),
              ),
            ],

            if (notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Text(
                  '📝 $notes',
                  style: TextStyle(fontSize: 11, color: Colors.brown.shade800),
                ),
              ),
            ],

            const Divider(height: 14),

            // Financial Summary Breakdown
            if (taxAmount > 0 || subtotal > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal (Base):', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                  Text(CurrencyService.format(subtotal > 0 ? subtotal : (attachment.price - taxAmount)),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                ],
              ),
              if (taxAmount > 0) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Tax:', style: TextStyle(fontSize: 11, color: Colors.purple.shade700)),
                    Text('+${CurrencyService.format(taxAmount)}',
                        style: TextStyle(fontSize: 11, color: Colors.purple.shade800, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
              const SizedBox(height: 4),
            ],

            // Grand Total Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Total (${items.length} Items, $totalQty Qty):',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                ),
                Text(
                  CurrencyService.format(attachment.price),
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quotation Action Buttons: Send Order, Create PO, Download PDF
            Column(
              children: [
                Row(
                  children: [
                    // Button 1: Download Quotation PDF
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 14, color: Color(0xFF1E40AF)),
                          label: const Text('Download PDF', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                          onPressed: () {
                            final ctrl = context.read<CommunityController>();
                            _generateAndDownloadDocumentPdf(
                              docType: 'Quotation',
                              docNo: quoteNo,
                              senderName: msg.senderName,
                              senderGstin: msg.senderGstin,
                              senderCity: msg.senderCity,
                              senderPhone: msg.senderPhone,
                              receiverName: widget.conversation.getDisplayTitle(ctrl.currentMerchantId, ctrl.currentMerchantName),
                              receiverGstin: widget.conversation.getDisplayGstin(ctrl.currentMerchantId, ctrl.currentProperty?.gstNo),
                              receiverCity: widget.conversation.regionCity,
                              items: items,
                              subtotal: subtotal > 0 ? subtotal : (attachment.price - taxAmount),
                              taxAmount: taxAmount,
                              grandTotal: attachment.price,
                              notes: notes,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Button 2: Instant Send Order directly into chat
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF15803D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(Icons.flash_on, size: 14),
                          label: const Text('Instant Order', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                          onPressed: () => _instantSendOrderFromQuote(context, msg, metadata, items),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Button 3: Open Full Purchase Order Screen
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E40AF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.shopping_cart_checkout, size: 15),
                    label: Text(
                      'Create PO / Order All (${items.length} Items)',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PurchaseOrderScreen(
                            supplierName: msg.senderName,
                            draftItems: items.map((i) => {
                              'item_code': i['item_code'],
                              'item_name': i['item_name'],
                              'rate': i['rate'],
                              'quantity': i['quantity'],
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 5. Single Product Card (Fallback / Default)
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withValues(alpha: 0.9) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isMe ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2, size: 28, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(attachment.title,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    Text(attachment.subtitle,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    if (attachment.price > 0)
                      Text(CurrencyService.format(attachment.price),
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.green)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.shopping_cart_checkout, size: 14),
              label: const Text('Create PO / Order Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PurchaseOrderScreen(
                      supplierName: msg.senderName,
                      draftItems: [
                        {
                          'item_name': attachment.title,
                          'rate': attachment.price,
                          'quantity': 1,
                        }
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _instantSendOrderFromQuote(
    BuildContext context,
    ChatMessage msg,
    Map<String, dynamic> metadata,
    List<dynamic> items,
  ) async {
    final quoteNo = metadata['quotation_no']?.toString() ?? 'QT-${msg.attachment?.id ?? ""}';
    final grandTotal = msg.attachment?.price ?? 0.0;
    final poNo = 'PO-${DateTime.now().millisecondsSinceEpoch % 100000}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shopping_cart_checkout, color: Color(0xFF15803D)),
            SizedBox(width: 8),
            Text('Confirm Instant Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Do you want to send an official Purchase Order ($poNo) for Quotation $quoteNo (${items.length} items, Total: ${CurrencyService.format(grandTotal)}) to ${msg.senderName}?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Send Order'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final attachment = ChatAttachment(
        type: 'PURCHASE_ORDER',
        id: 'po_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Purchase Order $poNo (Ref $quoteNo)',
        subtitle: 'Net: ${CurrencyService.format(grandTotal)} • ${items.length} Products',
        price: grandTotal,
        metadata: {
          ...metadata,
          'po_no': poNo,
          'quotation_ref': quoteNo,
          'status': 'CONFIRMED_ORDER',
        },
      );

      await _handleSend(
        content: '🛒 Order Confirmed: Placed Purchase Order $poNo against Quotation $quoteNo (Total: ${CurrencyService.format(grandTotal)})',
        attachment: attachment,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF15803D),
            content: Text('✅ Purchase Order $poNo successfully sent to ${msg.senderName}!'),
          ),
        );
      }
    }
  }

  Widget _buildRichMentionText(String content, bool isDeleted, bool isMe, ThemeData theme) {

    if (isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              isMe ? 'You deleted this message' : 'This message was deleted',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      );
    }

    final mentionRegex = RegExp(r'(@[a-zA-Z0-9_-]+)');
    final matches = mentionRegex.allMatches(content);
    if (matches.isEmpty) {
      return Text(
        content,
        style: TextStyle(
          fontSize: 13.5,
          color: isMe ? theme.colorScheme.onPrimaryContainer : Colors.black87,
        ),
      );
    }

    final List<TextSpan> spans = [];
    int lastEnd = 0;

    for (var match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      final mentionText = match.group(0)!;
      spans.add(
        TextSpan(
          text: mentionText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isMe ? Colors.blue.shade900 : Colors.blueAccent.shade700,
          ),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 13.5,
          color: isMe ? theme.colorScheme.onPrimaryContainer : Colors.black87,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
              tooltip: 'Share Product or PO',
              onPressed: () => _showAttachmentPicker(context),
            ),
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type message or type @ to mention a business...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
            const SizedBox(width: 6),
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: _handleSend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
