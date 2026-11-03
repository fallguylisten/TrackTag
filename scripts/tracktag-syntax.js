// TrackTag: switch title annotations to the new syntax, through Music.
//   {!poor quality!}  ->  !poor quality!     (review flags)
//   {REVIEW}          ->  !review!
//   {108 > 127}       ->  <108 > 127>         (personal annotations)
//
//   osascript -l JavaScript ~/Music/TrackTag/tracktag-syntax.js dryrun
//   osascript -l JavaScript ~/Music/TrackTag/tracktag-syntax.js apply
// apply saves ~/Music/TrackTag/undo-syntax-<date>.json first; revert it with
//   osascript -l JavaScript ~/Music/TrackTag/tracktag-migrate.js revert ~/Music/TrackTag/undo-syntax-<date>.json
ObjC.import('Foundation');
function path(p) { return ObjC.unwrap($(p).stringByExpandingTildeInPath); }
function convert(name) {
  return name
    .replace(/\{\s*REVIEW\s*\}/gi, '!review!')
    .replace(/\{!\s*([^{}!]+?)\s*!\}/g, '!$1!')
    .replace(/\{([^{}]+)\}/g, '<$1>');
}
function run(argv) {
  var mode = argv[0] || 'dryrun';
  var lib = Application('Music').libraryPlaylists[0];
  var names = lib.tracks.name(), pids = lib.tracks.persistentID();
  var plan = [];
  for (var i = 0; i < names.length; i++) {
    var n = String(names[i] || ''); if (n.indexOf('{') < 0) continue;
    var c = convert(n); if (c !== n) plan.push({ i: i, pid: pids[i], old: n, nu: c });
  }
  var lines = plan.map(function (p) { return '  ' + p.old + '\n    -> ' + p.nu; });
  if (mode !== 'apply') return 'DRY RUN: ' + plan.length + ' titles would change.\n' + lines.join('\n');
  var undo = plan.map(function (p) { return { pid: p.pid, index: p.i, title: p.old, old: { name: p.old } }; });
  var f = path('~/Music/TrackTag/undo-syntax-' + new Date().toISOString().slice(0, 10) + '.json');
  $(JSON.stringify(undo)).writeToFileAtomicallyEncodingError(f, true, $.NSUTF8StringEncoding, null);
  plan.forEach(function (p) {
    var t = lib.tracks[p.i];
    if (t.persistentID() !== p.pid) t = lib.tracks.whose({ persistentID: p.pid })[0];
    t.name = p.nu;
  });
  return 'Changed ' + plan.length + ' titles. Undo file: ' + f + '\n' + lines.join('\n');
}
