#!/bin/bash
# TrackTag cleanup: runs the three steps in the right order, all through Music.
#   1. longtail.json        tag cleanup + the 4 !replace! flags
#   2. restore-flags.json   the 4 flags again (skipped as "already done" if step 1 wrote them)
#   3. syntax               {!x!} -> !x!, {REVIEW} -> !review!, {x} -> <x>
#
#   bash ~/Music/TrackTag/tracktag-cleanup.sh dryrun   (shows what each step would do, changes nothing)
#   bash ~/Music/TrackTag/tracktag-cleanup.sh apply
# Each step saves its own undo file in ~/Music/TrackTag.

MODE="${1:-dryrun}"
DIR=~/Music/TrackTag
if [ "$MODE" != "dryrun" ] && [ "$MODE" != "apply" ]; then echo "Use: dryrun or apply"; exit 1; fi

echo "== 1/3 Long-tail tag cleanup"
osascript -l JavaScript "$DIR/tracktag-migrate.js" "$MODE" longtail.json || exit 1
echo
echo "== 2/3 Replace flags"
osascript -l JavaScript "$DIR/tracktag-migrate.js" "$MODE" restore-flags.json || exit 1
echo
echo "== 3/3 Title syntax"
if [ "$MODE" = "dryrun" ]; then
  echo "(The syntax dry run reads titles as they are now, so it won't show the flags steps 1-2 would add.)"
fi
osascript -l JavaScript "$DIR/tracktag-syntax.js" "$MODE" || exit 1
echo
echo "Done ($MODE)."
