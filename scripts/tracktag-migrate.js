// TrackTag one-time migration — writes the agreed tag changes through Apple Music.
//
// Usage (Terminal):
//   osascript -l JavaScript ~/Music/TrackTag/tracktag-migrate.js dryrun [changes-file.json]
//   osascript -l JavaScript ~/Music/TrackTag/tracktag-migrate.js apply [changes-file.json]
//   osascript -l JavaScript ~/Music/TrackTag/tracktag-migrate.js revert ~/Music/TrackTag/undo-<date>.json
//
// dryrun : reads Music, compares with changes.json, writes dryrun-<date>.tsv. Changes nothing.
// apply  : saves undo-<date>.json (current values of every field it will touch), then writes
//          only the "ready" changes through Music and saves applied-<date>.tsv.
// revert : puts back the values saved in an undo file.
//
// A track is only changed if its current values still match the Nov 2 library export.
// If you edited a song since then, it is reported as "changed since export" and skipped.

ObjC.import('Foundation');

var DIR = '~/Music/TrackTag/';
var FIELDS = ['name', 'artist', 'composer', 'comment', 'genre', 'rating'];

function path(p) { return ObjC.unwrap($(p).stringByExpandingTildeInPath); }
function readFile(p) {
  var s = $.NSString.stringWithContentsOfFileEncodingError(path(p), $.NSUTF8StringEncoding, null);
  if (!s || s.isNil()) throw new Error('Cannot read ' + p);
  return ObjC.unwrap(s);
}
function writeFile(p, txt) {
  $(txt).writeToFileAtomicallyEncodingError(path(p), true, $.NSUTF8StringEncoding, null);
}
function stamp() { return new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19); }
function cell(v) { return String(v === undefined || v === null ? '' : v).replace(/[\t\r\n]+/g, ' '); }
function norm(v) { return v === undefined || v === null ? '' : v; }

function readLibrary(lib) {
  // Bulk reads are fast; one Apple Event per field.
  var pids = lib.tracks.persistentID();
  var cols = {};
  FIELDS.forEach(function (f) { cols[f] = lib.tracks[f](); });
  var byPid = {};
  for (var i = 0; i < pids.length; i++) {
    var cur = {};
    FIELDS.forEach(function (f) { cur[f] = norm(cols[f][i]); });
    byPid[pids[i]] = { index: i, cur: cur };
  }
  return byPid;
}

function classify(changes, byPid) {
  return changes.map(function (c) {
    var hit = byPid[c.pid];
    if (!hit) return { c: c, status: 'missing from library' };
    var fields = Object.keys(c.new);
    var done = fields.every(function (f) { return hit.cur[f] === c.new[f]; });
    if (done) return { c: c, hit: hit, status: 'already done' };
    var same = fields.every(function (f) { return hit.cur[f] === norm(c.old[f]) || hit.cur[f] === c.new[f]; });
    return { c: c, hit: hit, status: same ? 'ready' : 'changed since export' };
  });
}

function report(rows, file) {
  var out = ['status\tpersistent id\ttitle\tartist\tfield\tcurrent\tnew\treview note'];
  rows.forEach(function (r) {
    Object.keys(r.c.new).forEach(function (f) {
      out.push([r.status, r.c.pid, r.c.title, r.c.artist, f,
        r.hit ? r.hit.cur[f] : '', r.c.new[f],
        [r.c.review, r.c.starNote].filter(Boolean).join('; ')].map(cell).join('\t'));
    });
  });
  writeFile(file, out.join('\n'));
}

function summary(rows) {
  var counts = {};
  rows.forEach(function (r) { counts[r.status] = (counts[r.status] || 0) + 1; });
  var fieldCounts = {};
  rows.filter(function (r) { return r.status === 'ready'; }).forEach(function (r) {
    Object.keys(r.c.new).forEach(function (f) { fieldCounts[f] = (fieldCounts[f] || 0) + 1; });
  });
  return 'Tracks: ' + JSON.stringify(counts) + '\nFields to write: ' + JSON.stringify(fieldCounts);
}

function trackFor(lib, pid, index) {
  var t = lib.tracks[index];
  try { if (t.persistentID() === pid) return t; } catch (e) {}
  var found = lib.tracks.whose({ persistentID: pid });
  return found.length ? found[0] : null;
}

function writeFields(t, values) {
  Object.keys(values).forEach(function (f) { t[f] = values[f]; });
}

function run(argv) {
  var mode = argv[0] || 'dryrun';
  var Music = Application('Music');
  Music.includeStandardAdditions = true;
  var lib = Music.libraryPlaylists[0];

  if (mode === 'revert') {
    if (!argv[1]) return 'Give the undo file: revert ~/Music/TrackTag/undo-<date>.json';
    var undo = JSON.parse(readFile(argv[1]));
    var ok = 0, failed = [];
    undo.forEach(function (u) {
      try {
        var t = trackFor(lib, u.pid, u.index);
        if (!t) throw new Error('not found');
        writeFields(t, u.old); ok++;
      } catch (e) { failed.push(u.pid + ' ' + u.title + ': ' + e.message); }
    });
    return 'Reverted ' + ok + ' tracks.' + (failed.length ? '\nFailed:\n' + failed.join('\n') : '');
  }

  var changes = JSON.parse(readFile(DIR + (argv[1] || 'changes.json')));
  var rows = classify(changes, readLibrary(lib));
  var when = stamp();

  if (mode === 'dryrun') {
    var file = DIR + 'dryrun-' + when + '.tsv';
    report(rows, file);
    return 'DRY RUN — nothing was changed.\n' + summary(rows) + '\nReport: ' + path(file);
  }

  if (mode !== 'apply') return 'Unknown mode: ' + mode + ' (use dryrun, apply or revert)';

  var ready = rows.filter(function (r) { return r.status === 'ready'; });
  var undoRows = ready.map(function (r) {
    var old = {};
    Object.keys(r.c.new).forEach(function (f) { old[f] = r.hit.cur[f]; });
    return { pid: r.c.pid, index: r.hit.index, title: r.c.title, old: old };
  });
  var undoFile = DIR + 'undo-' + when + '.json';
  writeFile(undoFile, JSON.stringify(undoRows));

  var done = 0, errors = [];
  ready.forEach(function (r, i) {
    try {
      var t = trackFor(lib, r.c.pid, r.hit.index);
      if (!t) throw new Error('not found');
      writeFields(t, r.c.new);
      r.status = 'written'; done++;
    } catch (e) { r.status = 'error: ' + e.message; errors.push(r.c.title + ': ' + e.message); }
    if ((i + 1) % 100 === 0) console.log('…' + (i + 1) + ' / ' + ready.length);
  });
  var applied = DIR + 'applied-' + when + '.tsv';
  report(rows, applied);
  return 'Wrote ' + done + ' tracks.\n' + summary(rows) +
    '\nUndo file: ' + path(undoFile) + '\nLog: ' + path(applied) +
    (errors.length ? '\nErrors:\n' + errors.join('\n') : '');
}
