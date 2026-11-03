// TrackTag delete — removes the tracks listed in delete.json from Apple Music
// and moves their files to ~/Music/TrackTag/Deleted (empty that folder yourself when sure).
//
//   osascript -l JavaScript ~/Music/TrackTag/tracktag-delete.js dryrun   (lists what it would do)
//   osascript -l JavaScript ~/Music/TrackTag/tracktag-delete.js apply
//
// Removing a track from Music also removes it from every playlist. Rekordbox and Serato
// will show these as missing; remove them there too.

ObjC.import('Foundation');
var DIR = '~/Music/TrackTag/';
function path(p) { return ObjC.unwrap($(p).stringByExpandingTildeInPath); }
function readFile(p) {
  var s = $.NSString.stringWithContentsOfFileEncodingError(path(p), $.NSUTF8StringEncoding, null);
  if (!s || s.isNil()) throw new Error('Cannot read ' + p);
  return ObjC.unwrap(s);
}
function writeFile(p, txt) { $(txt).writeToFileAtomicallyEncodingError(path(p), true, $.NSUTF8StringEncoding, null); }

function run(argv) {
  var mode = argv[0] || 'dryrun';
  var list = JSON.parse(readFile(DIR + 'delete.json'));
  var Music = Application('Music');
  var lib = Music.libraryPlaylists[0];
  var fm = $.NSFileManager.defaultManager;
  var bin = path(DIR + 'Deleted');
  var lines = [], log = [];

  if (mode === 'apply') fm.createDirectoryAtPathWithIntermediateDirectoriesAttributesError(bin, true, $(), null);

  list.forEach(function (d) {
    var hits = lib.tracks.whose({ persistentID: d.pid });
    if (!hits.length) { lines.push('not found (already gone?)  ' + d.title); return; }
    var t = hits[0], file = null;
    try { var loc = t.location(); if (loc) file = loc.toString(); } catch (e) {}
    var plists = [];
    try { plists = Music.userPlaylists.whose({ smart: false })().filter(function (p) {
      return p.tracks.whose({ persistentID: d.pid }).length > 0; }).map(function (p) { return p.name(); }); } catch (e) {}
    var info = d.title + ' — ' + d.artist + (plists.length ? '  [in: ' + plists.join(', ') + ']' : '');
    if (mode !== 'apply') { lines.push('would delete  ' + info + '\n    file: ' + (file || 'none')); return; }
    var moved = '';
    if (file && fm.fileExistsAtPath(file)) {
      var name = ObjC.unwrap($(file).lastPathComponent);
      var dest = bin + '/' + d.pid + ' ' + name;
      if (fm.moveItemAtPathToPathError(file, dest, null)) moved = dest; else moved = 'MOVE FAILED, file left at ' + file;
    }
    Music.delete(t);
    lines.push('deleted  ' + info + (moved ? '\n    file → ' + moved : ''));
    log.push({ pid: d.pid, title: d.title, artist: d.artist, file: file, movedTo: moved, playlists: plists });
  });

  if (mode === 'apply') {
    var f = DIR + 'deleted-' + new Date().toISOString().slice(0, 10) + '.json';
    writeFile(f, JSON.stringify(log, null, 1));
    return lines.join('\n') + '\nLog: ' + path(f);
  }
  return 'DRY RUN — nothing changed.\n' + lines.join('\n');
}
