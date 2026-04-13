#!/bin/bash
# Automated test battery for the romweasel queue feature.
# Runs on the MiSTer. Targets the three Codex-review fix paths plus
# end-to-end sanity. Uses /tmp/rw_test as destination so nothing
# lands in real game folders.
set -u
PASS=0; FAIL=0
pass() { printf "  PASS  %s\n" "$*"; PASS=$((PASS+1)); }
fail() { printf "  FAIL  %s\n" "$*"; FAIL=$((FAIL+1)); }
section() { printf "\n=== %s ===\n" "$*"; }

RW=/media/fat/Scripts/romweasel.sh
WRK=/media/fat/Scripts/.config/romweasel
QD=$WRK/queue
TMPDEST=/tmp/rw_test

reset() {
    rm -rf "$QD" "$TMPDEST"
    mkdir -p "$QD" "$TMPDEST"
}

make_item() {
    local slug=$1 tag=$2 size=${3:-1000} dest=${4:-$TMPDEST}
    local url_base=${5:-https://archive.org/download/nointro.atari-2600}
    local ts=$(date +%s%N)
    local dir=$QD/${ts}_${slug}
    mkdir -p "$dir"
    jq -n --arg tag "$tag" --arg filename "$tag" --arg core "TEST" \
        --arg core_url "$url_base" --arg dest_dir "$dest" \
        --arg size "$size" --arg sha1 "" --arg added_at "$ts" \
        '{tag:$tag, filename:$filename, core:$core, core_url:$core_url, dest_dir:$dest_dir, size:$size, sha1:$sha1, added_at:$added_at}' \
        > "$dir/meta.json"
    echo queued > "$dir/status"
    echo 0 > "$dir/progress"
    printf '%s' "$dir"
}

wait_status() {
    local dir=$1 want=$2 timeout=${3:-30}
    for i in $(seq 1 $timeout); do
        [[ -f $dir/status ]] || { sleep 1; continue; }
        local s=$(<"$dir/status")
        if [[ "$s" == "$want" ]]; then return 0; fi
        sleep 1
    done
    return 1
}

count_status() {
    local want=$1 n=0
    for d in "$QD"/*/; do
        [[ -f $d/status ]] || continue
        [[ $(<"$d/status") == "$want" ]] && n=$((n+1))
    done
    echo $n
}

################################################################
section "T1: RCE safety — command sub in filename"
reset
rm -f /tmp/rce_pwn
d=$(make_item rce 'evil$(touch /tmp/rce_pwn)file.7z' 100 $TMPDEST)
# Run worker for up to 4s; it should try to fetch the literal URL
# (which will 404), not execute the touch command.
timeout 4 zsh $RW --worker "$d" >/dev/null 2>&1
if [[ -f /tmp/rce_pwn ]]; then
    fail "/tmp/rce_pwn was created (RCE!)"
else
    pass "command substitution in filename not executed"
fi
if [[ -f $d/worker.log ]] && grep -q 'evil%24%28touch' $d/worker.log; then
    pass "URL encoded literally (no shell expansion)"
else
    fail "URL encoding check — worker.log:"
    cat $d/worker.log 2>&1 | head -3 | sed 's/^/        /'
fi

################################################################
section "T2: Single item end-to-end"
reset
d=$(make_item single 'Zoo Keeper Sounds (USA) (Proto).7z' 1096 $TMPDEST)
zsh $RW --dispatcher >/dev/null 2>&1 &
DPID=$!
if wait_status "$d" done 30; then
    pass "status=done within 30s"
else
    fail "status=$(cat $d/status) after 30s"
fi
wait $DPID 2>/dev/null
if [[ -f "$TMPDEST/Zoo Keeper Sounds (USA) (Proto).a26" ]]; then
    pass "extracted .a26 at destination"
else
    fail "extracted file missing"
fi
if [[ -f "$d/download.part" ]]; then
    fail "download.part leaked on success"
else
    pass "download.part cleaned up"
fi
if [[ -f "$d/wget.pid" ]]; then
    fail "wget.pid leaked on success"
else
    pass "wget.pid cleaned up"
fi

################################################################
section "T3: Concurrency cap (max=3, 5 real items queued)"
reset
# Five verified Neo Geo CD chds (1-7 MB each — big enough to
# overlap on MiSTer wifi for the peak-count observation window).
CHD_ITEMS=(
    "Puzzle Bobble ~ Bust-A-Move (Japan) (En,Ja).chd"
    "Andro Dunos (France) (Unl).chd"
    "League Bowling (Japan) (En,Ja).chd"
    "Bang^2 Busters (France) (En,Ja) (Unl).chd"
    "Flying Power Disc ~ Windjammers (Japan) (En,Ja).chd"
)
URL=https://archive.org/download/snk-neo-geo-cd-redump-collection
for i in 1 2 3 4 5; do
    make_item "c${i}" "${CHD_ITEMS[$((i-1))]}" 5000000 $TMPDEST "$URL" >/dev/null
done
echo 3 > $QD/.max_concurrent
zsh $RW --dispatcher >/dev/null 2>&1 &
DPID=$!
# Peak observation — poll aggressively during dispatcher startup
peak_running=0
for i in $(seq 1 40); do
    n=$(count_status running)
    (( n > peak_running )) && peak_running=$n
    sleep 0.25
done
if (( peak_running == 3 )); then
    pass "peak running count == 3 (max_concurrent)"
elif (( peak_running > 3 )); then
    fail "peak running count = $peak_running (ABOVE cap of 3)"
else
    fail "peak running count = $peak_running (BELOW 3 — dispatcher underfilling)"
fi
# Kill the long download (Flying Power Disc ~115MB) to avoid
# blocking the rest of the test battery.
for d in $QD/*/; do
    [[ -f $d/worker.pid ]] || continue
    [[ $(<$d/status) == running ]] || continue
    kill -TERM $(<$d/worker.pid) 2>/dev/null
    [[ -f $d/wget.pid ]] && kill -CONT $(<$d/wget.pid) 2>/dev/null
    [[ -f $d/wget.pid ]] && kill -TERM $(<$d/wget.pid) 2>/dev/null
done
sleep 2
[[ -f $QD/.dispatcher.pid ]] && kill -TERM $(<$QD/.dispatcher.pid) 2>/dev/null
wait $DPID 2>/dev/null
# Completion count is informational only — the test aborts mid-run
# to keep total wall time bounded, so most items don't actually
# finish. The peak_running check above is the real assertion.
done_n=$(count_status done)
failed_n=$(count_status failed)
echo "  INFO  done=$done_n failed=$failed_n (informational; test abort kills runners)"

################################################################
section "T4: Pause actually stops wget"
reset
# Use a 100+ MB file so the test has enough wall time to send
# STOP and observe a frozen progress counter before wget finishes.
# Flying Power Disc is ~115MB; over MiSTer wifi that's ~2 minutes.
BIG='Flying Power Disc ~ Windjammers (Japan) (En,Ja).chd'
URL=https://archive.org/download/snk-neo-geo-cd-redump-collection
d=$(make_item pause "$BIG" 120000000 $TMPDEST "$URL")
zsh $RW --dispatcher >/dev/null 2>&1 &
DPID=$!
# Wait for wget.pid to appear (up to 5s)
for i in 1 2 3 4 5; do
    [[ -f $d/wget.pid ]] && break
    sleep 1
done
if [[ ! -f $d/wget.pid ]]; then
    fail "wget.pid never appeared (worker didn't start?)"
else
    WGET_PID=$(<$d/wget.pid)
    pass "wget.pid captured: $WGET_PID"
    # Wait for wget to actually start writing bytes
    progress=0
    for i in 1 2 3 4 5 6 7 8 9 10; do
        if [[ -s $d/progress ]]; then
            progress=$(cat $d/progress 2>/dev/null)
            [[ -z $progress ]] && progress=0
            (( progress > 0 )) && break
        fi
        sleep 1
    done
    # Send STOP first, then let any in-flight writes settle for 2s
    # (the worker's poll interval is 1s) before recording the
    # baseline. This avoids the test race where `before` is read
    # while wget still has unflushed bytes in transit.
    kill -STOP $WGET_PID 2>/dev/null
    sleep 2
    before=$(cat $d/progress 2>/dev/null)
    [[ -z $before ]] && before=0
    sleep 3
    after=$(cat $d/progress 2>/dev/null)
    [[ -z $after ]] && after=0
    # Check proc state — should be 'T' (stopped)
    state=$(awk '/^State:/ {print $2}' /proc/$WGET_PID/status 2>/dev/null || echo gone)
    if [[ "$state" == "T" ]]; then
        pass "wget process State=T (stopped)"
    else
        fail "wget process State=$state (expected T)"
    fi
    if (( after == before )); then
        pass "progress frozen while paused (before=$before after=$after)"
    else
        fail "progress continued while paused ($before -> $after)"
    fi
    # Resume and verify forward progress
    kill -CONT $WGET_PID 2>/dev/null
    sleep 3
    after2=$(cat $d/progress 2>/dev/null)
    [[ -z $after2 ]] && after2=0
    if (( after2 > after )); then
        pass "progress resumed (after=$after after2=$after2)"
    else
        fail "progress did not resume ($after -> $after2)"
    fi
    # Cleanup — kill worker to stop the download
    [[ -f $d/worker.pid ]] && kill -TERM $(<$d/worker.pid) 2>/dev/null
    [[ -f $d/wget.pid ]] && kill -CONT $(<$d/wget.pid) 2>/dev/null
    [[ -f $d/wget.pid ]] && kill -TERM $(<$d/wget.pid) 2>/dev/null
fi
# Stop the dispatcher
[[ -f $QD/.dispatcher.pid ]] && kill -TERM $(<$QD/.dispatcher.pid) 2>/dev/null
wait $DPID 2>/dev/null

################################################################
section "T5: Install failure preserves partial file"
reset
# Point at a non-writable dest so the mv/extract step fails.
# Use a small Atari 2600 file that downloads quickly.
d=$(make_item fail 'Zoo Keeper Sounds (USA) (Proto).7z' 1096 /proc/1)
zsh $RW --worker "$d" >/dev/null 2>&1
if [[ $(<$d/status) == "failed" ]]; then
    pass "status=failed on install error"
else
    fail "status=$(cat $d/status), expected failed"
fi
if [[ -f $d/download.part ]]; then
    pass "download.part preserved for retry"
else
    fail "download.part missing — not recoverable"
fi
if grep -q "ERROR: install step exited" $d/worker.log 2>/dev/null; then
    pass "worker.log has install-failure entry"
else
    fail "worker.log missing install-failure entry"
fi

################################################################
section "T6: Kill-on-exit — worker trap stops wget"
reset
# Spawn the worker DIRECTLY without a dispatcher so nothing
# restarts the item after we kill it. This isolates the trap
# behaviour from dispatcher reconciliation logic.
d=$(make_item kill "$BIG" 5000000 $TMPDEST "$URL")
echo running > $d/status
zsh $RW --worker "$d" >/dev/null 2>&1 &
WORKER_PID=$!
# Wait for worker to spawn wget
for i in 1 2 3 4 5; do
    [[ -f $d/wget.pid ]] && break
    sleep 1
done
if [[ ! -f $d/wget.pid ]]; then
    fail "wget never started"
else
    WGET_PID=$(<$d/wget.pid)
    kill -TERM $WORKER_PID 2>/dev/null
    sleep 2
    if kill -0 $WGET_PID 2>/dev/null; then
        fail "wget still alive after worker TERM"
        kill -KILL $WGET_PID 2>/dev/null
    else
        pass "wget killed when worker received SIGTERM"
    fi
    if [[ $(<$d/status) == "queued" ]]; then
        pass "status reverted to queued after signal (trap fired)"
    else
        fail "status=$(cat $d/status) after kill (expected queued)"
        echo "    ---worker.log tail---"
        tail -20 $d/worker.log 2>/dev/null | sed 's/^/    /'
        echo "    ---"
    fi
fi
wait $WORKER_PID 2>/dev/null

################################################################
section "Summary"
echo "PASS=$PASS FAIL=$FAIL"
rm -rf "$QD" "$TMPDEST"
exit $(( FAIL > 0 ))
