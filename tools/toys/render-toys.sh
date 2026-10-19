#!/bin/bash
# Render stills of design/toy-turntables.html with headless Chrome (the pipeline from handoff.md section 7).
# Each job is "<outname>|<query>|<width>x<height>", e.g. "bedroom|shot=sheet&set=Bedroom|1600x1000".
# Two at a time; anything that comes out tiny (a dropped GPU frame) is retried up to 3 times.
# usage (from the repo root, in Git Bash): bash tools/toys/render-toys.sh <outdir under design/> job1 job2 ...
cd "$(dirname "$0")/../.." || exit 1
OUTDIR=$1; shift
RUN=$(date +%s%N)
SCR=${TOY_RENDER_SCRATCH:-${TMPDIR:-/tmp}/toy-renders}
CHROME="/c/Program Files/Google/Chrome/Application/chrome.exe"
PAGE="file:///C:/Users/Dylan%20Wu/Downloads/Roblox%20brainrot%20game/design/toy-turntables.html"
mkdir -p "design/$OUTDIR" "$SCR/png"
one() {
	local job=$1 slot=$2 name query size png try
	IFS='|' read -r name query size <<<"$job"
	size=${size:-1600x1000}
	for try in 1 2 3; do
		png="$SCR/png/$name-$RUN.png"
		rm -f "$png"
		timeout 150 "$CHROME" --headless=new --window-size="${size/x/,}" --hide-scrollbars --enable-unsafe-swiftshader \
			--user-data-dir="$(cygpath -w "$SCR/cprof/$RUN-$slot-$try")" --virtual-time-budget=7000 \
			--screenshot="$(cygpath -w "$png")" "$PAGE?$query&w=${size%x*}&h=${size#*x}" >/dev/null 2>&1
		[ -f "$png" ] || continue
		ffmpeg -v error -y -i "$png" -q:v 3 "design/$OUTDIR/$name.jpg"
		if [ "$(stat -c %s "design/$OUTDIR/$name.jpg")" -gt 40000 ]; then
			echo "done $name"
			return
		fi
	done
	echo "FAILED $name"
}
i=0
for job in "$@"; do
	one "$job" $((i % 2)) &
	i=$((i + 1))
	if ((i % 2 == 0)); then wait; fi
done
wait
