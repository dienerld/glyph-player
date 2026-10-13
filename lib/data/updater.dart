import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'downloader.dart';

const _latestRelease =
    'https://api.github.com/repos/dienerld/glyph-player/releases/latest';

/// A published release newer than the running app.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.pageUrl,
    this.assetUrl,
  });
  final String version, notes, pageUrl;

  /// The archive/installer for this platform; null when there is none.
  final Uri? assetUrl;
}

/// What the app can do with an [UpdateInfo] on this machine.
enum UpdateMode {
  /// Download the archive and overwrite the install folder (Linux, user-owned).
  replaceFiles,

  /// Run the setup.exe silently (Windows, installed with the installer).
  runInstaller,

  /// Not self-updatable (system package, portable zip): open the release page.
  openPage,
}

List<int> _parts(String v) =>
    v.split('-').first.split('.').map((s) => int.tryParse(s) ?? 0).toList();

/// True when [candidate] (`0.3.1`) is a higher version than [current].
bool isNewer(String candidate, String current) {
  final a = _parts(candidate), b = _parts(current);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

String? get _assetSuffix => Platform.isLinux
    ? '-linux-x64.tar.gz'
    : Platform.isWindows
    ? '-setup.exe'
    : null;

/// The latest release when it is newer than [current]; null when up to date.
/// Throws on network or parse errors (the caller decides how loud to be).
Future<UpdateInfo?> fetchUpdate(
  String current, {
  required http.Client client,
  String? assetSuffix,
}) async {
  final res = await client
      .get(
        Uri.parse(_latestRelease),
        headers: {'Accept': 'application/vnd.github+json'},
      )
      .timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) {
    throw HttpException(
      'HTTP ${res.statusCode}',
      uri: Uri.parse(_latestRelease),
    );
  }
  final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  final version = (json['tag_name'] as String).replaceFirst(RegExp('^v'), '');
  if (!isNewer(version, current)) return null;
  final suffix = assetSuffix ?? _assetSuffix;
  Uri? asset;
  for (final a in (json['assets'] as List? ?? const [])) {
    if (suffix != null && (a['name'] as String).endsWith(suffix)) {
      asset = Uri.parse(a['browser_download_url'] as String);
      break;
    }
  }
  return UpdateInfo(
    version: version,
    notes: (json['body'] as String?) ?? '',
    pageUrl: json['html_url'] as String,
    assetUrl: asset,
  );
}

String get _installDir => p.dirname(Platform.resolvedExecutable);

/// Probed once (top-level finals are lazy): the answer does not change while
/// running, and the probe touches the disk.
final _installDirWritable = _writable(_installDir);

bool _writable(String dir) {
  try {
    File(p.join(dir, '.glyph-write-test'))
      ..createSync()
      ..deleteSync();
    return true;
  } on FileSystemException {
    return false;
  }
}

UpdateMode updateMode(UpdateInfo u) {
  if (u.assetUrl == null) return UpdateMode.openPage;
  if (Platform.isLinux && _installDirWritable) {
    return UpdateMode.replaceFiles;
  }
  // Inno Setup drops its uninstaller beside the exe; a portable zip has none.
  if (Platform.isWindows &&
      File(p.join(_installDir, 'unins000.exe')).existsSync()) {
    return UpdateMode.runInstaller;
  }
  return UpdateMode.openPage;
}

Future<void> _run(String cmd, List<String> args) async {
  final r = await Process.run(cmd, args);
  if (r.exitCode != 0) {
    throw ProcessException(cmd, args, '${r.stderr}', r.exitCode);
  }
}

Future<void> openUrl(String url) => Process.start(
  Platform.isWindows ? 'rundll32' : 'xdg-open',
  Platform.isWindows ? ['url.dll,FileProtocolHandler', url] : [url],
  mode: ProcessStartMode.detached,
);

/// Applies [u] per [updateMode]. On success the app restarts (or hands over to
/// the installer) and this never returns; failures throw with the install left
/// untouched, because the only step that modifies it is the final copy.
Future<void> installUpdate(UpdateInfo u) async {
  final mode = updateMode(u);
  if (mode == UpdateMode.openPage) return openUrl(u.pageUrl);

  final work = await Directory.systemTemp.createTemp('glyph-update-');
  final exe = Platform.resolvedExecutable;
  try {
    final file = File(p.join(work.path, p.basename(u.assetUrl!.path)));
    await downloadTo(u.assetUrl!, file);
    if (mode == UpdateMode.runInstaller) {
      await Process.start(file.path, [
        '/SILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
      ], mode: ProcessStartMode.detached);
      exit(0); // the installer replaces the files once we are gone
    }
    final fresh = Directory(p.join(work.path, 'new'))..createSync();
    await _run('tar', [
      '-xzf',
      file.path,
      '-C',
      fresh.path,
      '--strip-components=1',
    ]);
    if (!File(p.join(fresh.path, 'glyph_player')).existsSync()) {
      throw const FormatException('Pacote de atualização inválido');
    }
    // Only for manual installs; not part of the running app.
    final extras = Directory(p.join(fresh.path, 'linux'));
    if (extras.existsSync()) extras.deleteSync(recursive: true);
    for (final f in fresh.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.md'),
    )) {
      f.deleteSync();
    }
    // Unlink-then-write: the running binary cannot be opened for writing.
    await _run('cp', [
      '-r',
      '--remove-destination',
      '${fresh.path}/.',
      _installDir,
    ]);
  } finally {
    if (mode == UpdateMode.replaceFiles) await work.delete(recursive: true);
  }
  await Process.start(exe, [], mode: ProcessStartMode.detached);
  exit(0);
}
