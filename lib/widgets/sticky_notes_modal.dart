import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import '../controllers/notes/user_notes_controller.dart';
import '../models/notes/user_note_model.dart';

class StickyNotesModal extends StatefulWidget {
  final UserNotesController controller;

  const StickyNotesModal({Key? key, required this.controller}) : super(key: key);

  static void show(BuildContext context, UserNotesController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StickyNotesModal(controller: controller),
    );
  }

  @override
  State<StickyNotesModal> createState() => _StickyNotesModalState();
}

class _StickyNotesModalState extends State<StickyNotesModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  UserNote? _activeEditingNote;
  String _activeSection = 'notes'; // 'notes', 'archive', 'trash'

  final List<Map<String, dynamic>> _noteColors = [
    {'name': 'Default Dark', 'hex': '#202124', 'bg': Color(0xFF202124), 'border': Color(0xFF3C4043), 'text': Colors.white},
    {'name': 'Yellow', 'hex': '#FEF08A', 'bg': Color(0xFFFEF08A), 'border': Color(0xFFFDE047), 'text': Color(0xFF1E293B)},
    {'name': 'Mint', 'hex': '#A7F3D0', 'bg': Color(0xFFA7F3D0), 'border': Color(0xFF6EE7B7), 'text': Color(0xFF1E293B)},
    {'name': 'Sky Blue', 'hex': '#BAE6FD', 'bg': Color(0xFFBAE6FD), 'border': Color(0xFF7DD3FC), 'text': Color(0xFF1E293B)},
    {'name': 'Pink', 'hex': '#FBCFE8', 'bg': Color(0xFFFBCFE8), 'border': Color(0xFFF472B6), 'text': Color(0xFF1E293B)},
    {'name': 'Lavender', 'hex': '#DDD6FE', 'bg': Color(0xFFDDD6FE), 'border': Color(0xFFC084FC), 'text': Color(0xFF1E293B)},
    {'name': 'Coral', 'hex': '#FFEDD5', 'bg': Color(0xFFFFEDD5), 'border': Color(0xFFFDBA74), 'text': Color(0xFF1E293B)},
  ];

  static final List<Map<String, String>> _taggedEmojis = [
    {'emoji': '📌', 'tags': 'pin push mark note mandatory alert'},
    {'emoji': '🚨', 'tags': 'alert emergency warning danger urgent red'},
    {'emoji': '💰', 'tags': 'money cash dollar payment wealth bag due bill'},
    {'emoji': '🥛', 'tags': 'milk drink dairy food item grocery'},
    {'emoji': '⚡', 'tags': 'electric power fast flash quick energy'},
    {'emoji': '📦', 'tags': 'package box stock inventory delivery item'},
    {'emoji': '🛒', 'tags': 'cart shopping buy store retail order'},
    {'emoji': '👥', 'tags': 'people staff users team customers group'},
    {'emoji': '🍽️', 'tags': 'food restaurant table order dining eat'},
    {'emoji': '👨‍🍳', 'tags': 'chef kitchen cook staff restaurant'},
    {'emoji': '📲', 'tags': 'phone mobile call app notification contact'},
    {'emoji': '🚚', 'tags': 'truck delivery transport shipping supplier'},
    {'emoji': '🏢', 'tags': 'office building store branch shop company'},
    {'emoji': '🌙', 'tags': 'night evening dark nightshift close'},
    {'emoji': '💵', 'tags': 'cash bill money rupee note payment'},
    {'emoji': '⚙️', 'tags': 'settings config gear options system'},
    {'emoji': '🔐', 'tags': 'lock security safe key password secret'},
    {'emoji': '📋', 'tags': 'clipboard task list todo memo summary'},
    {'emoji': '📝', 'tags': 'note write edit text paper document'},
    {'emoji': '📅', 'tags': 'calendar date schedule event reminder'},
    {'emoji': '⏰', 'tags': 'alarm clock time reminder scheduled'},
    {'emoji': '📊', 'tags': 'bar chart report analytics stats sales'},
    {'emoji': '📈', 'tags': 'growth up chart profit sales increase'},
    {'emoji': '📉', 'tags': 'loss down chart decrease sales drop'},
    {'emoji': '🎯', 'tags': 'target goal focus objective aim'},
    {'emoji': '💡', 'tags': 'idea light bulb suggestion tip note'},
    {'emoji': '🏷️', 'tags': 'label tag price discount sale category'},
    {'emoji': '✅', 'tags': 'check done finished completed success true yes'},
    {'emoji': '❌', 'tags': 'cross cancel delete false remove no'},
    {'emoji': '⭐', 'tags': 'star favorite important top rate rating'},
    {'emoji': '🔥', 'tags': 'fire hot trending popular urgent priority'},
    {'emoji': '🚀', 'tags': 'rocket launch fast speed growth startup'},
    {'emoji': '🔑', 'tags': 'key access pass login password secret'},
    {'emoji': '🔒', 'tags': 'lock closed private secure protected'},
    {'emoji': '🔓', 'tags': 'unlock open accessible public'},
    {'emoji': '😀', 'tags': 'happy smile face joy expression positive'},
    {'emoji': '😃', 'tags': 'smiley happy smile face joy laugh'},
    {'emoji': '😄', 'tags': 'smile happy face laugh joy grin'},
    {'emoji': '😁', 'tags': 'grin happy smile face teeth joy'},
    {'emoji': '😅', 'tags': 'sweat smile happy relief nervous'},
    {'emoji': '😎', 'tags': 'cool sunglasses confident awesome style'},
    {'emoji': '😍', 'tags': 'love heart eyes like favorite adore'},
    {'emoji': '🥳', 'tags': 'party celebrate festival cheer fun event'},
    {'emoji': '🤔', 'tags': 'thinking think ponder question wonder idea'},
    {'emoji': '😴', 'tags': 'sleep sleepy tired rest night late'},
    {'emoji': '🤑', 'tags': 'money rich dollar cash profit wealth'},
    {'emoji': '🤖', 'tags': 'bot ai robot assistant automated lynx'},
    {'emoji': '👍', 'tags': 'thumbsup approve agree good like yes ok'},
    {'emoji': '👎', 'tags': 'thumbsdown disapprove disagree bad dislike no'},
    {'emoji': '👌', 'tags': 'ok perfect fine excellent complete done'},
    {'emoji': '👏', 'tags': 'clap applaud praise celebrate congrats'},
    {'emoji': '🤝', 'tags': 'handshake deal agreement partnership partner'},
    {'emoji': '💪', 'tags': 'strong power muscle effort success win'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadNotes(section: 'notes');
    });
  }

  void _switchSection(String section) {
    setState(() {
      _activeSection = section;
      _activeEditingNote = null;
    });
    widget.controller.loadNotes(section: section);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171717) : const Color(0xFFF1F5F9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _activeEditingNote != null
              ? _buildGoogleKeepEditorView(_activeEditingNote!)
              : _buildGoogleKeepBoardView(isDark),
        ),
      ),
    );
  }

  // ================= 1. GOOGLE KEEP BOARD VIEW =================
  Widget _buildGoogleKeepBoardView(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF171717) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: _activeSection == 'notes'
                    ? 'Search Keep Notes...'
                    : (_activeSection == 'archive' ? 'Search Archived Notes...' : 'Search Trash...'),
                hintStyle: TextStyle(
                  color: (isDark ? Colors.white54 : const Color(0xFF64748B)).withOpacity(0.65),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 8),
                  child: Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    size: 18,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 0),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          size: 16,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          _searchCtrl.clear();
                          widget.controller.loadNotes(query: '', section: _activeSection);
                        },
                      ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        size: 18,
                      ),
                      padding: const EdgeInsets.only(right: 12),
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                suffixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 0),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (val) => widget.controller.loadNotes(query: val, section: _activeSection),
            ),
          ),
        ),
      ),
      floatingActionButton: _activeSection == 'notes'
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded, size: 22),
              label: const Text('Create a note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: () async {
                final newNote = UserNote(
                  id: 0,
                  outletId: 0,
                  title: '',
                  content: '',
                  colorHex: isDark ? '#202124' : '#FEF08A',
                  reminderType: 'NONE',
                );
                setState(() {
                  _activeEditingNote = newNote;
                });
              },
            )
          : null,
      body: Column(
        children: [
          // Section Switcher Navigation Bar (Notes, Archive, Trash)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                _buildSectionTab('notes', '💡 Notes', isDark),
                const SizedBox(width: 8),
                _buildSectionTab('archive', '📥 Archive', isDark),
                const SizedBox(width: 8),
                _buildSectionTab('trash', '🗑️ Trash', isDark),
                if (_activeSection == 'trash') ...[
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    icon: const Icon(Icons.delete_forever, size: 16),
                    label: const Text('Empty Trash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      await widget.controller.emptyTrash();
                    },
                  ),
                ],
              ],
            ),
          ),

          if (_activeSection == 'trash')
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: const Text(
                '📌 Notes in Trash are deleted permanently after 30 days.',
                style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
              ),
            ),

          // Notes Masonry Grid
          Expanded(
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                if (widget.controller.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allNotes = widget.controller.notes;
                if (allNotes.isEmpty) {
                  String emptyTitle = 'Notes you add appear here';
                  if (_activeSection == 'archive') emptyTitle = 'Your archived notes appear here';
                  if (_activeSection == 'trash') emptyTitle = 'No notes in Trash';

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _activeSection == 'trash'
                              ? Icons.delete_outline
                              : (_activeSection == 'archive' ? Icons.archive_outlined : Icons.lightbulb_outline),
                          size: 64,
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          emptyTitle,
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ],
                    ),
                  );
                }

                final pinnedNotes = allNotes.where((n) => n.isPinned && _activeSection == 'notes').toList();
                final otherNotes = allNotes.where((n) => !n.isPinned || _activeSection != 'notes').toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                  children: [
                    if (pinnedNotes.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Pinned',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      _buildStandard3ColumnGrid(pinnedNotes, isDark),
                      const SizedBox(height: 20),
                    ],
                    if (otherNotes.isNotEmpty) ...[
                      if (pinnedNotes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'Others',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      _buildStandard3ColumnGrid(otherNotes, isDark),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTab(String sectionKey, String label, bool isDark) {
    final isSelected = _activeSection == sectionKey;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _switchSection(sectionKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  // 3-Column Standard Responsive Grid (Max 3 notes per row, 20px padding)
  Widget _buildStandard3ColumnGrid(List<UserNote> notes, bool isDark) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 3;
    if (width < 600) {
      crossAxisCount = 1;
    } else if (width < 900) {
      crossAxisCount = 2;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: 210,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: notes.length,
      itemBuilder: (context, idx) {
        return _buildKeepCard(notes[idx], isDark);
      },
    );
  }

  // Google Keep Card Item - Tapping ANYWHERE on the card opens the note editor instantly!
  Widget _buildKeepCard(UserNote note, bool isDark) {
    Color bg = isDark ? const Color(0xFF202124) : Colors.white;
    Color border = isDark ? const Color(0xFF3C4043) : const Color(0xFFE2E8F0);
    Color textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    for (final c in _noteColors) {
      if (c['hex'].toString().toLowerCase() == note.colorHex.toLowerCase()) {
        bg = c['bg'];
        border = c['border'];
        textColor = c['text'];
        break;
      }
    }

    final hasReminder = note.reminderType != 'NONE';
    String reminderText = '';
    if (hasReminder) {
      String startPrefix = '';
      if (note.reminderDate != null) {
        startPrefix = '${DateFormat('dd MMM').format(note.reminderDate!)}, ';
      }
      if (note.reminderType == 'DAILY') {
        reminderText = '$startPrefix${note.reminderTime ?? "09:00 AM"} 🔁 Daily';
      } else if (note.reminderType == 'WEEKLY') {
        reminderText = '$startPrefix${note.reminderTime ?? "09:00 AM"} 🔁 Weekly';
      } else if (note.reminderType == 'MONTHLY') {
        reminderText = '$startPrefix${note.reminderTime ?? "09:00 AM"} 🔁 Monthly';
      } else if (note.reminderDate != null) {
        reminderText = DateFormat('dd MMM, HH:mm').format(note.reminderDate!);
      } else if (note.reminderTime != null) {
        reminderText = note.reminderTime!;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (_activeSection != 'trash') {
              setState(() {
                _activeEditingNote = note;
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: buildMarkdownRichText(
                        note.title.isNotEmpty ? note.title : 'Untitled Note',
                        TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: textColor,
                          decoration: note.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 2,
                        isSelectable: false, // Allows tapping anywhere on title to open note
                      ),
                    ),
                    if (_activeSection == 'trash')
                      IconButton(
                        icon: const Icon(Icons.restore_from_trash, size: 18, color: Colors.blue),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        tooltip: 'Restore Note',
                        onPressed: () => widget.controller.restoreNote(note.id),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: buildMarkdownRichText(
                    note.content,
                    TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: textColor.withOpacity(0.85),
                      decoration: note.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 5,
                    isSelectable: false, // Allows tapping anywhere on content to open note
                  ),
                ),
                if (hasReminder) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 13, color: textColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            reminderText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper Markdown & Clickable URL Rich Text Parser
  static Widget buildMarkdownRichText(String rawText, TextStyle baseStyle, {int? maxLines, bool isSelectable = true}) {
    if (rawText.trim().isEmpty) return const SizedBox.shrink();

    final lines = rawText.split('\n');
    final List<InlineSpan> spans = [];

    for (int i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (i > 0) spans.add(const TextSpan(text: '\n'));

      // Check for Heading (# Title)
      if (line.startsWith('# ')) {
        spans.add(TextSpan(
          text: line.substring(2),
          style: baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 14) * 1.2, fontWeight: FontWeight.bold),
        ));
        continue;
      }

      // Check for Bullet (- Item or * Item)
      if (line.startsWith('- ') || line.startsWith('* ')) {
        spans.add(TextSpan(
          text: '• ',
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
        line = line.substring(2);
      }

      // Parse URLs, Markdown Links [text](url), **bold**, *italic*, and ~~strikethrough~~
      final RegExp reg = RegExp(r'(\[([^\]]+)\]\(([^)]+)\)|https?://[^\s]+|www\.[^\s]+|\*\*(.*?)\*\*|\*(.*?)\*|~~(.*?)~~)');
      int lastMatchEnd = 0;

      for (final match in reg.allMatches(line)) {
        if (match.start > lastMatchEnd) {
          spans.add(TextSpan(text: line.substring(lastMatchEnd, match.start), style: baseStyle));
        }

        final matchText = match.group(0)!;

        // 1. Markdown Link [text](url)
        if (match.group(2) != null && match.group(3) != null) {
          final linkText = match.group(2)!;
          final linkUrl = match.group(3)!;
          spans.add(TextSpan(
            text: linkText,
            style: baseStyle.copyWith(
              color: Colors.blue.shade700,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.bold,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                final target = linkUrl.startsWith('http') ? linkUrl : 'https://$linkUrl';
                OpenFile.open(target);
              },
          ));
        }
        // 2. Direct Raw URL (http://... or www....)
        else if (matchText.startsWith('http://') || matchText.startsWith('https://') || matchText.startsWith('www.')) {
          final target = matchText.startsWith('http') ? matchText : 'https://$matchText';
          spans.add(TextSpan(
            text: matchText,
            style: baseStyle.copyWith(
              color: Colors.blue.shade700,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                OpenFile.open(target);
              },
          ));
        }
        // 3. Bold (**text**)
        else if (matchText.startsWith('**') && matchText.endsWith('**')) {
          spans.add(TextSpan(
            text: matchText.substring(2, matchText.length - 2),
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ));
        }
        // 4. Italic (*text*)
        else if (matchText.startsWith('*') && matchText.endsWith('*')) {
          spans.add(TextSpan(
            text: matchText.substring(1, matchText.length - 1),
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ));
        }
        // 5. Strikethrough (~~text~~)
        else if (matchText.startsWith('~~') && matchText.endsWith('~~')) {
          spans.add(TextSpan(
            text: matchText.substring(2, matchText.length - 2),
            style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
          ));
        }

        lastMatchEnd = match.end;
      }

      if (lastMatchEnd < line.length) {
        spans.add(TextSpan(text: line.substring(lastMatchEnd), style: baseStyle));
      }
    }

    if (!isSelectable) {
      return Text.rich(
        TextSpan(children: spans, style: baseStyle),
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
      );
    }

    return SelectableText.rich(
      TextSpan(children: spans, style: baseStyle),
      maxLines: maxLines,
    );
  }

  // ================= 2. GOOGLE KEEP EDITOR VIEW =================
  Widget _buildGoogleKeepEditorView(UserNote note) {
    return _GoogleKeepNoteEditor(
      key: ValueKey('editor_${note.id}'),
      note: note,
      noteColors: _noteColors,
      taggedEmojis: _taggedEmojis,
      onSaveAndBack: (updatedNote) async {
        if (updatedNote.title.trim().isNotEmpty || updatedNote.content.trim().isNotEmpty) {
          if (updatedNote.id == 0) {
            await widget.controller.createNote(updatedNote);
          } else {
            await widget.controller.updateNote(updatedNote.id, updatedNote);
          }
        } else if (updatedNote.id > 0) {
          await widget.controller.moveToTrash(updatedNote.id);
        }
        setState(() {
          _activeEditingNote = null;
        });
      },
      onCopy: (copiedNote) async {
        setState(() {
          _activeEditingNote = copiedNote;
        });
      },
      onArchive: (id) async {
        if (id > 0) {
          await widget.controller.toggleArchive(id);
        }
        setState(() {
          _activeEditingNote = null;
        });
      },
      onTrash: (id) async {
        if (id > 0) {
          await widget.controller.moveToTrash(id);
        }
        setState(() {
          _activeEditingNote = null;
        });
      },
    );
  }
}

// Google Keep Full Screen Note Editor with Keyboard Shortcuts (Ctrl+B, Ctrl+I, Ctrl+K)
class _GoogleKeepNoteEditor extends StatefulWidget {
  final UserNote note;
  final List<Map<String, dynamic>> noteColors;
  final List<Map<String, String>> taggedEmojis;
  final Function(UserNote) onSaveAndBack;
  final Function(UserNote) onCopy;
  final Function(int) onArchive;
  final Function(int) onTrash;

  const _GoogleKeepNoteEditor({
    Key? key,
    required this.note,
    required this.noteColors,
    required this.taggedEmojis,
    required this.onSaveAndBack,
    required this.onCopy,
    required this.onArchive,
    required this.onTrash,
  }) : super(key: key);

  @override
  State<_GoogleKeepNoteEditor> createState() => _GoogleKeepNoteEditorState();
}

class _GoogleKeepNoteEditorState extends State<_GoogleKeepNoteEditor> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late String _currentColorHex;
  late bool _isPinned;
  late bool _isArchived;
  late String _reminderType;
  DateTime? _reminderDate;
  String? _reminderTime;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note.title);
    _contentCtrl = TextEditingController(text: widget.note.content);
    _currentColorHex = widget.note.colorHex;
    _isPinned = widget.note.isPinned;
    _isArchived = widget.note.isArchived;
    _reminderType = widget.note.reminderType;
    _reminderDate = widget.note.reminderDate;
    _reminderTime = widget.note.reminderTime;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  UserNote _buildCurrentNotePayload() {
    return UserNote(
      id: widget.note.id,
      outletId: widget.note.outletId,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      colorHex: _currentColorHex,
      isPinned: _isPinned,
      isCompleted: widget.note.isCompleted,
      isArchived: _isArchived,
      isTrashed: widget.note.isTrashed,
      reminderType: _reminderType,
      reminderDate: _reminderDate,
      reminderTime: _reminderTime,
    );
  }

  void _applyFormatting(String prefix, String suffix) {
    final text = _contentCtrl.text;
    final selection = _contentCtrl.selection;
    if (selection.isValid && selection.start != selection.end) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
      _contentCtrl.text = newText;
      _contentCtrl.selection = TextSelection(
        baseOffset: selection.start + prefix.length,
        extentOffset: selection.end + prefix.length,
      );
    } else {
      final pos = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
      final newText = text.replaceRange(pos, pos, '$prefix$suffix');
      _contentCtrl.text = newText;
      _contentCtrl.selection = TextSelection.collapsed(offset: pos + prefix.length);
    }
  }

  void _showInsertLinkDialog() {
    final linkTextCtrl = TextEditingController();
    final linkUrlCtrl = TextEditingController(text: 'https://');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.link, color: Colors.blue),
              SizedBox(width: 8),
              Text('Insert Link (Ctrl+K)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: linkTextCtrl,
                decoration: const InputDecoration(labelText: 'Link Title (e.g. Android Docs)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: linkUrlCtrl,
                decoration: const InputDecoration(labelText: 'URL (e.g. https://developer.android.com)', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                final title = linkTextCtrl.text.trim();
                final url = linkUrlCtrl.text.trim();
                if (url.isNotEmpty) {
                  final formattedLink = '[${title.isEmpty ? url : title}]($url)';
                  _applyFormatting(formattedLink, '');
                }
              },
              child: const Text('Insert Link'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg = isDark ? const Color(0xFF202124) : Colors.white;
    Color textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    for (final c in widget.noteColors) {
      if (c['hex'].toString().toLowerCase() == _currentColorHex.toLowerCase()) {
        bg = c['bg'];
        textColor = c['text'];
        break;
      }
    }

    final hasReminder = _reminderType != 'NONE';
    String reminderText = '';
    if (hasReminder) {
      String startPrefix = '';
      if (_reminderDate != null) {
        startPrefix = '${DateFormat('dd MMM').format(_reminderDate!)}, ';
      }
      if (_reminderType == 'DAILY') {
        reminderText = '$startPrefix${_reminderTime ?? "09:00 AM"} 🔁 Daily';
      } else if (_reminderType == 'WEEKLY') {
        reminderText = '$startPrefix${_reminderTime ?? "09:00 AM"} 🔁 Weekly';
      } else if (_reminderType == 'MONTHLY') {
        reminderText = '$startPrefix${_reminderTime ?? "09:00 AM"} 🔁 Monthly';
      } else if (_reminderType == 'YEARLY') {
        reminderText = '$startPrefix${_reminderTime ?? "09:00 AM"} 🔁 Yearly';
      } else if (_reminderDate != null) {
        reminderText = DateFormat('dd MMM, HH:mm').format(_reminderDate!);
      } else if (_reminderTime != null) {
        reminderText = _reminderTime!;
      }
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () => _applyFormatting('**', '**'),
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () => _applyFormatting('**', '**'),
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () => _applyFormatting('*', '*'),
        const SingleActivator(LogicalKeyboardKey.keyI, meta: true): () => _applyFormatting('*', '*'),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _showInsertLinkDialog,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _showInsertLinkDialog,
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => widget.onSaveAndBack(_buildCurrentNotePayload()),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: textColor,
              ),
              tooltip: 'Pin note',
              onPressed: () {
                setState(() {
                  _isPinned = !_isPinned;
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.add_alert_outlined, color: textColor),
              tooltip: 'Add reminder',
              onPressed: _showReminderPicker,
            ),
            IconButton(
              icon: Icon(
                _isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                color: textColor,
              ),
              tooltip: _isArchived ? 'Unarchive note' : 'Archive note',
              onPressed: () => widget.onArchive(widget.note.id),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: bg,
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.color_lens_outlined, color: textColor),
                tooltip: 'Color Palette',
                onPressed: _showColorPalettePicker,
              ),
              // "T" Formatting Toolbar Button
              IconButton(
                icon: Icon(Icons.format_size_rounded, color: textColor),
                tooltip: 'Formatting, Shortcuts & Emojis',
                onPressed: _showFormattingToolbar,
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.more_vert, color: textColor),
                tooltip: 'More Options',
                onPressed: _showMoreOptionsMenu,
              ),
            ],
          ),
        ),
        body: Container(
          color: bg,
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Blending Title Input Box
              TextField(
                controller: _titleCtrl,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                decoration: InputDecoration(
                  filled: false,
                  fillColor: Colors.transparent,
                  hintText: 'Title',
                  hintStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor.withOpacity(0.4),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              if (hasReminder) ...[
                GestureDetector(
                  onTap: _showReminderPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 14, color: textColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            reminderText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Direct Inline Typing Content Area
              Expanded(
                child: TextField(
                  controller: _contentCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    filled: false,
                    fillColor: Colors.transparent,
                    hintText: 'Note',
                    hintStyle: TextStyle(
                      fontSize: 16,
                      color: textColor.withOpacity(0.4),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFormattingToolbar() {
    String emojiSearch = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final query = emojiSearch.toLowerCase().trim();
            final filteredEmojis = widget.taggedEmojis.where((item) {
              if (query.isEmpty) return true;
              return item['tags']!.contains(query) || item['emoji']!.contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.55,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Formatting & Emojis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white60), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Formatting Chips & Shortcuts
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.format_bold, size: 16, color: Colors.blue),
                        label: const Text('Bold (Ctrl+B)'),
                        onPressed: () {
                          _applyFormatting('**', '**');
                          Navigator.pop(ctx);
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.format_italic, size: 16, color: Colors.blue),
                        label: const Text('Italic (Ctrl+I)'),
                        onPressed: () {
                          _applyFormatting('*', '*');
                          Navigator.pop(ctx);
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.link, size: 16, color: Colors.blue),
                        label: const Text('Insert Link (Ctrl+K)'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showInsertLinkDialog();
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.title, size: 16, color: Colors.blue),
                        label: const Text('Heading (# Title)'),
                        onPressed: () {
                          _applyFormatting('# ', '');
                          Navigator.pop(ctx);
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.format_list_bulleted, size: 16, color: Colors.blue),
                        label: const Text('Bullet (- Item)'),
                        onPressed: () {
                          _applyFormatting('- ', '');
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Searchable & Tagged Emoji Picker
                  TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search emojis (e.g. money, milk, pin, alert, star)...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white60),
                      filled: true,
                      fillColor: const Color(0xFF334155),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      setSheetState(() {
                        emojiSearch = val;
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // Tagged Scrollable Emoji Grid
                  Expanded(
                    child: filteredEmojis.isNotEmpty
                        ? GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                            itemCount: filteredEmojis.length,
                            itemBuilder: (context, index) {
                              final item = filteredEmojis[index];
                              final emoji = item['emoji']!;
                              return InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  _applyFormatting(emoji, '');
                                  Navigator.pop(ctx);
                                },
                                child: Center(
                                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Text('No emojis found', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showColorPalettePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Color Theme', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.noteColors.map((c) {
                    final isSelected = _currentColorHex.toLowerCase() == c['hex'].toString().toLowerCase();
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentColorHex = c['hex'];
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c['bg'],
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? Colors.white : c['border'], width: isSelected ? 2.5 : 1),
                        ),
                        child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.blue) : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReminderPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add / Edit Reminder Alarm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.repeat_rounded, color: Colors.amberAccent),
                title: const Text('Daily Repeat (Everyday)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(_reminderType == 'DAILY' ? 'Active: ${_reminderTime ?? "09:00 AM"}' : 'Pick Start Date & Time for daily repeat', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final now = DateTime.now();
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _reminderDate ?? now.add(const Duration(days: 1)),
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: DateTime(2030),
                  );
                  if (pickedDate != null && context.mounted) {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 9, minute: 0),
                    );
                    final hour = pickedTime?.hour ?? 9;
                    final minute = pickedTime?.minute ?? 0;
                    final fullStartDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, hour, minute);

                    setState(() {
                      _reminderType = 'DAILY';
                      _reminderDate = fullStartDate;
                      if (pickedTime != null) {
                        _reminderTime = pickedTime.format(context);
                      } else {
                        _reminderTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                      }
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_repeat_rounded, color: Colors.purpleAccent),
                title: const Text('Weekly Repeat (Every Week)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(_reminderType == 'WEEKLY' ? 'Active: ${_reminderTime ?? "09:00 AM"}' : 'Pick Start Date & Time for weekly repeat', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final now = DateTime.now();
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _reminderDate ?? now.add(const Duration(days: 1)),
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: DateTime(2030),
                  );
                  if (pickedDate != null && context.mounted) {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 9, minute: 0),
                    );
                    final hour = pickedTime?.hour ?? 9;
                    final minute = pickedTime?.minute ?? 0;
                    final fullStartDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, hour, minute);

                    setState(() {
                      _reminderType = 'WEEKLY';
                      _reminderDate = fullStartDate;
                      if (pickedTime != null) {
                        _reminderTime = pickedTime.format(context);
                      } else {
                        _reminderTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                      }
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_rounded, color: Colors.blueAccent),
                title: const Text('Monthly Repeat (Every Month)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(_reminderType == 'MONTHLY' ? 'Active: ${_reminderTime ?? "09:00 AM"}' : 'Pick Start Date & Time for monthly repeat', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final now = DateTime.now();
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _reminderDate ?? now.add(const Duration(days: 1)),
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: DateTime(2030),
                  );
                  if (pickedDate != null && context.mounted) {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 9, minute: 0),
                    );
                    final hour = pickedTime?.hour ?? 9;
                    final minute = pickedTime?.minute ?? 0;
                    final fullStartDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, hour, minute);

                    setState(() {
                      _reminderType = 'MONTHLY';
                      _reminderDate = fullStartDate;
                      if (pickedTime != null) {
                        _reminderTime = pickedTime.format(context);
                      } else {
                        _reminderTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                      }
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_calendar_rounded, color: Colors.tealAccent),
                title: const Text('Specific Date & Time...', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                subtitle: const Text('One-time alarm on selected date', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final now = DateTime.now();
                  final firstValidDate = now.subtract(const Duration(days: 365));
                  DateTime initial = _reminderDate ?? now.add(const Duration(days: 1));
                  if (initial.isBefore(firstValidDate)) {
                    initial = now;
                  }

                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: firstValidDate,
                    lastDate: DateTime(2030),
                  );
                  if (pickedDate != null && context.mounted) {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: _reminderDate != null
                          ? TimeOfDay(hour: _reminderDate!.hour, minute: _reminderDate!.minute)
                          : TimeOfDay.now(),
                    );
                    final hour = pickedTime?.hour ?? 9;
                    final minute = pickedTime?.minute ?? 0;
                    final fullDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, hour, minute);

                    setState(() {
                      _reminderType = 'SPECIFIC_DATE';
                      _reminderDate = fullDate;
                      if (pickedTime != null) {
                        _reminderTime = pickedTime.format(context);
                      } else {
                        _reminderTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                      }
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined, color: Colors.redAccent),
                title: const Text('Delete Reminder', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  setState(() {
                    _reminderType = 'NONE';
                    _reminderDate = null;
                    _reminderTime = null;
                  });
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMoreOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.content_copy, color: Colors.white),
                title: const Text('Make a copy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (widget.note.id > 0) {
                    final copied = await UserNotesController().copyNote(widget.note.id);
                    if (copied != null) {
                      widget.onCopy(copied);
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Move to Trash', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onTrash(widget.note.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
