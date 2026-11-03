
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast_web/sembast_web.dart' as sembast_web;

late Database db;
late sembast.Database sembastDb;

final sembastStore =
    sembast.intMapStoreFactory.store('catatan');

const Color sage = Color(0xFF405747);
const Color cream = Color(0xFFF5F3EB);
const Color textDark = Color(0xFF29382F);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final factory = databaseFactoryFfiWeb;
  db = await factory.openDatabase('catatan_mahasiswa.db');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS catatan (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      judul TEXT NOT NULL,
      isi TEXT NOT NULL
    )
  ''');

  sembastDb = await sembast_web.databaseFactoryWeb
      .openDatabase('catatan_mahasiswa_sembast.db');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyNotes',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: cream,
        colorScheme: ColorScheme.fromSeed(seedColor: sage),
        fontFamily: 'Arial',
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, Object?>> notes = [];
  String searchText = '';
  String userName = 'Mahasiswa';
  bool loading = true;

  final List<Color> noteColors = const [
    Color(0xFFDDE7D9),
    Color(0xFFF1DFD1),
    Color(0xFFE9E4CF),
    Color(0xFFE3E5E8),
  ];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('nama_mahasiswa');

    final result = await db.query(
      'catatan',
      orderBy: 'id DESC',
    );

    if (!mounted) return;

    setState(() {
      userName = savedName ?? 'Mahasiswa';
      notes = result;
      loading = false;
    });
  }

  List<Map<String, Object?>> get filteredNotes {
    return notes.where((note) {
      final title = (note['judul'] ?? '').toString().toLowerCase();
      final content = (note['isi'] ?? '').toString().toLowerCase();
      final search = searchText.toLowerCase();

      return title.contains(search) || content.contains(search);
    }).toList();
  }

  Future<void> saveNote({
    int? id,
    required String title,
    required String content,
  }) async {
    if (id == null) {
      await db.insert('catatan', {
        'judul': title,
        'isi': content,
      });
    } else {
      await db.update(
        'catatan',
        {
          'judul': title,
          'isi': content,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    await loadData();
  }

  Future<void> deleteNote(int id) async {
    await db.delete(
      'catatan',
      where: 'id = ?',
      whereArgs: [id],
    );

    await loadData();
  }

  Future<void> showNoteForm({Map<String, Object?>? note}) async {
    final titleController = TextEditingController(
      text: note?['judul']?.toString() ?? '',
    );
    final contentController = TextEditingController(
      text: note?['isi']?.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            note == null ? 'Catatan Baru' : 'Edit Catatan',
            style: const TextStyle(
              color: sage,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Judul catatan',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Isi catatan',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Batal',
                style: TextStyle(color: sage),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: sage,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final title = titleController.text.trim();
                final content = contentController.text.trim();

                if (title.isEmpty || content.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Judul dan isi catatan harus diisi.'),
                    ),
                  );
                  return;
                }

                await saveNote(
                  id: note?['id'] as int?,
                  title: title,
                  content: content,
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    contentController.dispose();
  }

  Future<void> editProfile() async {
    final controller = TextEditingController(text: userName);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cream,
          title: const Text('Profil Pengguna'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nama mahasiswa',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: sage,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = controller.text.trim();

                if (name.isEmpty) return;

                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('nama_mahasiswa', name);

                if (!mounted) return;

                setState(() {
                  userName = name;
                });

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> confirmDelete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cream,
        title: const Text('Hapus Catatan?'),
        content: const Text(
          'Catatan ini akan dihapus secara permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFAD5D48),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await deleteNote(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedNotes = filteredNotes;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_stories_rounded,
                          color: sage,
                          size: 32,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'MyNotes.',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: sage,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Profil',
                          onPressed: editProfile,
                          icon: const Icon(
                            Icons.account_circle_rounded,
                            color: sage,
                            size: 34,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 15, 28, 20),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: sage,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR PERSONAL SPACE',
                            style: TextStyle(
                              color: Color(0xFFDDE7D9),
                              letterSpacing: 2,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Keep your ideas close.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 29,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Halo, $userName! Ayok buat catatan biar ga lupa pea?',
                            style: const TextStyle(
                              color: Color(0xFFE0E9DF),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: () => showNoteForm(),
                              icon: const Icon(Icons.add),
                              label: const Text('Buat Catatan Baru'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF5F3EB),
                                foregroundColor: sage,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SembastPage(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.storage_rounded,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Uji Coba Sembast',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          searchText = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari judul atau isi catatan...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: sage,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 4, 28, 15),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        const Text(
                          'Catatan Saya',
                          style: TextStyle(
                            color: textDark,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${notes.length} catatan',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(color: sage),
                    ),
                  )
                else if (displayedNotes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.note_alt_outlined,
                              size: 65,
                              color: sage.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              searchText.isEmpty
                                  ? 'Belum ada catatan'
                                  : 'Catatan tidak ditemukan',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            const SizedBox(height: 7),
                            const Text(
                              'Yuk, mulai tulis ide dan aktivitasmu.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 30),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 330,
                        mainAxisExtent: 205,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final note = displayedNotes[index];
                          final color =
                              noteColors[index % noteColors.length];

                          return Container(
                            padding: const EdgeInsets.all(19),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.sticky_note_2_outlined,
                                      color: sage,
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: 'Edit',
                                      onPressed: () =>
                                          showNoteForm(note: note),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 19,
                                        color: sage,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Hapus',
                                      onPressed: () => confirmDelete(
                                        note['id'] as int,
                                      ),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 19,
                                        color: Color(0xFFAD5D48),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  note['judul'].toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: textDark,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Text(
                                    note['isi'].toString(),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF626B61),
                                      height: 1.5,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const Text(
                                  'MyNotes',
                                  style: TextStyle(
                                    color: sage,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: displayedNotes.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// HALAMAN PENGUJIAN SEMBAST
// =====================================================

class SembastPage extends StatefulWidget {
  const SembastPage({super.key});

  @override
  State<SembastPage> createState() => _SembastPageState();
}

class _SembastPageState extends State<SembastPage> {
  List<sembast.RecordSnapshot<int, Map<String, Object?>>> notes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadSembastNotes();
  }

  Future<void> loadSembastNotes() async {
    final result = await sembastStore.find(sembastDb);

    if (!mounted) return;

    setState(() {
      notes = result;
      loading = false;
    });
  }

  Future<void> saveSembastNote({
    int? id,
    required String title,
    required String content,
  }) async {
    final data = <String, Object?>{
      'judul': title,
      'isi': content,
    };

    if (id == null) {
      await sembastStore.add(sembastDb, data);
    } else {
      await sembastStore.record(id).update(sembastDb, data);
    }

    await loadSembastNotes();
  }

  Future<void> deleteSembastNote(int id) async {
    await sembastStore.record(id).delete(sembastDb);
    await loadSembastNotes();
  }

  Future<void> showSembastForm({
    sembast.RecordSnapshot<int, Map<String, Object?>>? note,
  }) async {
    final titleController = TextEditingController(
      text: note?.value['judul']?.toString() ?? '',
    );

    final contentController = TextEditingController(
      text: note?.value['isi']?.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cream,
          title: Text(
            note == null ? 'Catatan Sembast Baru' : 'Edit Catatan Sembast',
            style: const TextStyle(
              color: sage,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Judul catatan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Isi catatan',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Batal',
                style: TextStyle(color: sage),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: sage,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final title = titleController.text.trim();
                final content = contentController.text.trim();

                if (title.isEmpty || content.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Judul dan isi catatan harus diisi.'),
                    ),
                  );
                  return;
                }

                await saveSembastNote(
                  id: note?.key,
                  title: title,
                  content: content,
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    contentController.dispose();
  }

  Future<void> confirmDeleteSembast(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cream,
        title: const Text('Hapus Catatan Sembast?'),
        content: const Text(
          'Catatan ini akan dihapus secara permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFAD5D48),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await deleteSembastNote(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        foregroundColor: sage,
        title: const Text(
          'Pengujian Sembast',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: sage,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SEMBAST DATABASE',
                        style: TextStyle(
                          color: Color(0xFFDDE7D9),
                          letterSpacing: 2,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Kelola Catatan Kamu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Halaman ini digunakan untuk menguji '
                        'penyimpanan data menggunakan Sembast.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Daftar Catatan Sembast',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${notes.length} catatan',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => showSembastForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Catatan Sembast'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sage,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(color: sage),
                        )
                      : notes.isEmpty
                          ? const Center(
                              child: Text(
                                'Belum ada catatan Sembast.\n'
                                'Tekan tombol tambah untuk membuat catatan.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                  height: 1.6,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: notes.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final note = notes[index];

                                return Card(
                                  color: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 8,
                                    ),
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xFFDDE7D9),
                                      child: Icon(
                                        Icons.sticky_note_2_outlined,
                                        color: sage,
                                      ),
                                    ),
                                    title: Text(
                                      note.value['judul'].toString(),
                                      style: const TextStyle(
                                        color: textDark,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Text(
                                        note.value['isi'].toString(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    trailing: Wrap(
                                      spacing: 0,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit',
                                          onPressed: () =>
                                              showSembastForm(note: note),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            color: sage,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Hapus',
                                          onPressed: () =>
                                              confirmDeleteSembast(note.key),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Color(0xFFAD5D48),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
