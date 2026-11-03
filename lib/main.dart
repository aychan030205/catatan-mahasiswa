import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  runApp(const CatatanMahasiswaApp());
}

class CatatanMahasiswaApp extends StatelessWidget {
  const CatatanMahasiswaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Catatan Mahasiswa',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 199, 114, 82),
        ),
        useMaterial3: true,
      ),
      home: const HalamanCatatan(),
    );
  }
}

class HalamanCatatan extends StatefulWidget {
  const HalamanCatatan({super.key});

  @override
  State<HalamanCatatan> createState() => _HalamanCatatanState();
}

class _HalamanCatatanState extends State<HalamanCatatan> {
  Database? database;
  List<Map<String, dynamic>> daftarCatatan = [];

  final TextEditingController namaController = TextEditingController();

  final Color warnaUtama =
      const Color.fromARGB(255, 199, 114, 82);

  @override
  void initState() {
    super.initState();
    inisialisasiAplikasi();
  }

  Future<void> inisialisasiAplikasi() async {
    await bukaDatabase();
    await muatNama();
    await bacaCatatan();
  }

  // Membuka database SQLite
  Future<void> bukaDatabase() async {
    database = await openDatabase(
      'catatan_mahasiswa.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE catatan (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            judul TEXT NOT NULL,
            isi TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // Mengambil nama dari SharedPreferences
  Future<void> muatNama() async {
    final prefs = await SharedPreferences.getInstance();

    namaController.text =
        prefs.getString('nama_mahasiswa') ?? '';

    if (mounted) {
      setState(() {});
    }
  }

  // Menyimpan nama ke SharedPreferences
  Future<void> simpanNama(String nama) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('nama_mahasiswa', nama);

    // Memperbarui nama agar langsung tampil di halaman utama
    namaController.text = nama;

    if (mounted) {
      setState(() {});
    }
  }

  // Menampilkan seluruh catatan dari database
  Future<void> bacaCatatan() async {
    if (database == null) return;

    final hasil = await database!.query(
      'catatan',
      orderBy: 'id DESC',
    );

    if (!mounted) return;

    setState(() {
      daftarCatatan = hasil;
    });
  }

  // Menambahkan catatan
  Future<void> tambahCatatan(
    String judul,
    String isi,
  ) async {
    await database!.insert('catatan', {
      'judul': judul,
      'isi': isi,
    });

    await bacaCatatan();
  }

  // Mengubah catatan
  Future<void> editCatatan(
    int id,
    String judul,
    String isi,
  ) async {
    await database!.update(
      'catatan',
      {
        'judul': judul,
        'isi': isi,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await bacaCatatan();
  }

  // Menghapus catatan
  Future<void> hapusCatatan(int id) async {
    await database!.delete(
      'catatan',
      where: 'id = ?',
      whereArgs: [id],
    );

    await bacaCatatan();
  }

  // Form tambah dan edit catatan
  void tampilkanForm({
    Map<String, dynamic>? catatan,
  }) {
    final judulController = TextEditingController(
      text: catatan?['judul'] ?? '',
    );

    final isiController = TextEditingController(
      text: catatan?['isi'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            catatan == null
                ? 'Tambah Catatan'
                : 'Edit Catatan',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: judulController,
                decoration: const InputDecoration(
                  labelText: 'Judul Catatan',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: isiController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Isi Catatan',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final judul =
                    judulController.text.trim();

                final isi =
                    isiController.text.trim();

                if (judul.isEmpty || isi.isEmpty) {
                  return;
                }

                if (catatan == null) {
                  await tambahCatatan(judul, isi);
                } else {
                  await editCatatan(
                    catatan['id'],
                    judul,
                    isi,
                  );
                }

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  // Menampilkan profil pengguna
  void tampilkanProfil() {
    final controller = TextEditingController(
      text: namaController.text,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Profil Pengguna'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nama Mahasiswa',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                await simpanNama(
                  controller.text.trim(),
                );

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  // Konfirmasi sebelum menghapus catatan
  void konfirmasiHapus(int id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Catatan'),
          content: const Text(
            'Yakin ingin menghapus catatan ini?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                await hapusCatatan(id);

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    namaController.dispose();
    database?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Catatan Mahasiswa',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: warnaUtama,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: tampilkanProfil,
            icon: const Icon(Icons.person),
            tooltip: 'Profil Pengguna',
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bagian sambutan pengguna
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: warnaUtama.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selamat Datang!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    namaController.text.isEmpty
                        ? 'Silakan isi nama melalui menu profil.'
                        : namaController.text,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Daftar Catatan',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            // Daftar catatan dari SQLite
            Expanded(
              child: daftarCatatan.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada catatan. Yuk, buat catatan!',
                      ),
                    )
                  : ListView.builder(
                      itemCount: daftarCatatan.length,
                      itemBuilder: (context, index) {
                        final catatan =
                            daftarCatatan[index];

                        return Card(
                          margin: const EdgeInsets.only(
                            bottom: 10,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  warnaUtama.withValues(
                                alpha: 0.2,
                              ),
                              child: Icon(
                                Icons.description,
                                color: warnaUtama,
                              ),
                            ),
                            title: Text(
                              catatan['judul'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(catatan['isi']),
                            trailing:
                                PopupMenuButton<String>(
                              onSelected: (pilihan) {
                                if (pilihan == 'edit') {
                                  tampilkanForm(
                                    catatan: catatan,
                                  );
                                } else if (pilihan ==
                                    'hapus') {
                                  konfirmasiHapus(
                                    catatan['id'],
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                const PopupMenuItem(
                                  value: 'hapus',
                                  child: Text('Hapus'),
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

      // Tombol tambah catatan
      floatingActionButton: FloatingActionButton(
        onPressed: () => tampilkanForm(),
        backgroundColor: warnaUtama,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}