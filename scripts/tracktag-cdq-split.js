// TrackTag: retire the CD-rip label. Each CDR/CDQ track becomes a download (HQ/DL) if its
// sound ceiling is Good (19.5 kHz or more), otherwise a rip (LQ/RIP). Ceilings come from the Nov 2 scan.
// Uses RIP/DL if your library already has those labels, otherwise LQ/HQ. Writes through Music.
//   osascript -l JavaScript ~/Music/TrackTag/tracktag-cdq-split.js dryrun
//   osascript -l JavaScript ~/Music/TrackTag/tracktag-cdq-split.js apply
var GOOD = ["80EBE3663FD7062C", "6B701077641990F9", "E4016597CD6AC474", "D097E8DADEF8A5BB", "26EBFE64B3FF8CB0", "04F48B9823F69B94", "49562DDB8FE811B3", "53F99461D2D9C355", "D01C9D0D1F6807A6", "FFD5E67D8C4CAE75", "5D1D0148DA658130", "03DF0161DFF0463B", "27614BD22637EB06", "8FF0872BA8BDEF7B", "E83C07706DC51151", "B58DFB010AAFBFCA", "04BAA2876D3D0948", "11A7D261FB4F8158", "C566C830DA7542CF", "D7A3C7489CA9F4AC", "48D2BA7CF35F613F", "5D49F1F024023CE2", "D3AFC8263F028BD1", "60F68A86288C899D", "CC4EA68992057DEC", "F399189D1E5B7853", "7B664C3E52389C0E", "68542332938E0DA5", "53DA180A17A8DF65", "12CB5D77B49242AA", "5C35EBC22737E3E4", "9E41924205DFFDCD", "908B141E14F9DD48", "A89FE573C24E483F", "F069BC1A161E9594", "5C48B7FE103061D6", "126EF75CB2D0BDCD", "B322DD0BEEDD21FB", "107DC81BAE17E208", "158ADA2EF3CFF357", "3ECFF11D5EF43730", "0D4BF694E0A54AF1"];
var POOR = ["5A8512AE7EFA3DF2", "FE06231EF776E284", "D533EC395C065DB1", "625FA2EC4A82D9BF", "D630E9A95A494E86", "16FCB411DC4E6397", "9DBB9808365392ED"];
function run(argv) {
  var mode = argv[0] || 'dryrun';
  var lib = Application('Music').libraryPlaylists[0];
  var g = lib.tracks.grouping(), names = lib.tracks.name(), pids = lib.tracks.persistentID();
  var newScheme = g.some(function (x) { x = String(x || '').trim(); return x === 'RIP' || x === 'DL'; });
  var HI = newScheme ? 'DL' : 'HQ', LO = newScheme ? 'RIP' : 'LQ';
  var good = {}, poor = {}; GOOD.forEach(function (p) { good[p] = 1; }); POOR.forEach(function (p) { poor[p] = 1; });
  var plan = [], unscanned = [];
  for (var i = 0; i < g.length; i++) {
    var cur = String(g[i] || '').trim();
    if (cur !== 'CDR' && cur !== 'CDQ') continue;
    if (good[pids[i]]) plan.push([i, HI]); else if (poor[pids[i]]) plan.push([i, LO]); else unscanned.push(names[i]);
  }
  var lines = plan.map(function (p) { return '  ' + p[1] + '  ' + names[p[0]]; });
  var tail = unscanned.length ? '\nNot in the scan, left as is:\n  ' + unscanned.join('\n  ') : '';
  if (mode !== 'apply') return 'DRY RUN: ' + plan.length + ' tracks would change.\n' + lines.join('\n') + tail;
  plan.forEach(function (p) {
    var t = lib.tracks[p[0]];
    if (t.persistentID() !== pids[p[0]]) t = lib.tracks.whose({ persistentID: pids[p[0]] })[0];
    t.grouping = p[1];
  });
  return 'Changed ' + plan.length + ' tracks.\n' + lines.join('\n') + tail;
}
