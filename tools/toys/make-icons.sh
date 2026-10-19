#!/bin/bash
# Render a transparent 256 px icon of every toy into design/toy-icons/<Id>.png (for the Index, shop and reviews).
# One headless-Chrome screenshot of design/toy-turntables.html?shot=icons, cut up with ffmpeg.
# usage (from the repo root, in Git Bash): bash tools/toys/make-icons.sh
cd "$(dirname "$0")/../.." || exit 1
SCR=${TOY_RENDER_SCRATCH:-${TMPDIR:-/tmp}/toy-renders}
CHROME="/c/Program Files/Google/Chrome/Application/chrome.exe"
PAGE="file:///C:/Users/Dylan%20Wu/Downloads/Roblox%20brainrot%20game/design/toy-turntables.html"
CELL=256
COLS=12
mkdir -p "$SCR" design/toy-icons
IDS=$(perl -MJSON::PP -e 'local $/; my $s = <STDIN>; $s =~ s/^.*?window\.TOY_DATA = //s; $s =~ s/;\s*$//;
	my $d = decode_json($s); print join(" ", map { map { $_->{Id} } @{ $_->{Toys} } } @{ $d->{sets} })' <design/toy-data.js)
N=$(wc -w <<<"$IDS")
ROWS=$(((N + COLS - 1) / COLS))
W=$((CELL * COLS))
H=$((CELL * ROWS))
RUN=$(date +%s%N)
PNG="$SCR/icons-$RUN.png"
timeout 200 "$CHROME" --headless=new --window-size=$W,$H --hide-scrollbars --default-background-color=00000000 \
	--user-data-dir="$(cygpath -w "$SCR/cprof/icons-$RUN")" --virtual-time-budget=5000 \
	--screenshot="$(cygpath -w "$PNG")" "$PAGE?shot=icons&set=All&cell=$CELL&w=$W&h=$H" >/dev/null 2>&1
[ -f "$PNG" ] || { echo "no screenshot"; exit 1; }
i=0
for id in $IDS; do
	ffmpeg -v error -y -i "$PNG" -vf "crop=$CELL:$CELL:$(((i % COLS) * CELL)):$(((i / COLS) * CELL))" "design/toy-icons/$id.png"
	i=$((i + 1))
done
echo "$i icons in design/toy-icons"
