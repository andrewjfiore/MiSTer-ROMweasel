#!/bin/zsh

# Script sets its own options and restores caller options on exit
setopt localoptions extendedglob pipefail warnnestedvar nullglob
autoload zmv

# Initialise all readonly global variables
init_static_globals () {
    typeset -gr ROMWEASEL_VERSION="MiSTer ROMweasel v0.9.15"

    # Required software to run
    typeset -gr XMLLINT=$(which xmllint)    || { print "ERROR: 'xmllint' not found" ; return 1 }
    typeset -gr CURL=$(which curl)          || { print "ERROR: 'curl' not found" ; return 1 }
    typeset -gr DIALOG=$(which dialog)      || { print "ERROR: 'dialog' not found" ; return 1 }
    typeset -gr SHA1SUM=$(which sha1sum)    || { print "ERROR: 'sha1sum' not found" ; return 1 }
    typeset -gr SZR=$(which 7zr)            || { print "ERROR: '7zr' not found" ; return 1 }
    # Why use zip. Sigh.
    typeset -gr UNZIP=$(which unzip)        || { print "ERROR: 'unzip' not found" ; return 1 }
    typeset -gr NUMFMT=$(which numfmt)      || { print "ERROR: 'numfmt' not found" ; return 1 }
    typeset -gr BC=$(which bc)              || { print "ERROR: 'bc' not found" ; return 1 }
    typeset -gr JQ=$(which jq)              || { print "ERROR: 'jq' not found" ; return 1 }

    # Stash all metadata here
    typeset -gr WRK_DIR="/media/fat/Scripts/.config/romweasel"
    #typeset -gr WRK_DIR="$(PWD)/metadata"
    # User configurable settings
    typeset -gr SETTINGS_SH="${WRK_DIR}/settings.sh"
    # Temporary location for compressed ROMs
    typeset -gr CACHE_DIR="${WRK_DIR}/cache"
    # If this file exists, skip downloading XML metadata files
    typeset -gr DLDONE="${WRK_DIR}/.dl_done"

    # Supported ROM repositories
    typeset -gra SUPPORTED_CORES=( \
        "NES"       "Nintendo Entertainment System" \
        "SNES"      "Super Nintendo" \
        "N64"       "Nintendo 64" \
        "GB"        "Nintendo GameBoy" \
        "GBC"       "Nintendo GameBoy Color" \
        "GBA"       "GameBoy Advance" \
        "TG16"      "NEC TurboGrafx16 / PC-Engine" \
        "TG16CD"    "NEC TurboGrafx16-CD / PC-Engine CD" \
        "SMS"       "SEGA Master System" \
        "GG"        "SEGA Game Gear" \
        "MD"        "SEGA Mega Drive" \
        "MCD"       "SEGA MegaCD / SegaCD" \
        "SS"        "SEGA Saturn" \
        "PSXUS"     "Sony PlayStation USA" \
        "PSXEU"     "Sony PlayStation Europe" \
        "PSXJP"     "Sony PlayStation Japan" \
        "PSXJP2"    "Sony PlayStation Japan #2" \
        "PSXMISC"   "Sony PlayStation Miscellaneous" \
        "AO486"     "0MHz DOS Collection" \
        "CD32"      "Amiga CD32" \
        "GNW"       "Game & Watch" \
        "WS"        "WonderSwan" \
        "WSC"       "WonderSwan Color" \
        "PV1000"    "Casio PV-1000" \
        "NEOGEO"    "SNK Neo Geo (AES/MVS)" \
        "NEOGEOCD"  "SNK Neo Geo CD" \
        "TDO"       "Panasonic 3DO" \
        "S32X"      "SEGA 32X" \
        "CDI"       "Philips CD-i" \
        "JAG"       "Atari Jaguar" \
        "A2600"     "Atari 2600" \
        "A5200"     "Atari 5200" \
        "A7800"     "Atari 7800" \
        "MSX"       "MSX / MSX1" \
        "C64"       "Commodore 64" \
    )

    # The prefix "NAME_" must match the core name in above list
    typeset -gr NES_URL="https://archive.org/download/nointro.nes-headered"
    typeset -gr NES_FILES_XML="nointro.nes-headered_files.xml"
    typeset -gr NES_META_XML="nointro.nes-headered_meta.xml"
    typeset -gr SNES_URL="https://archive.org/download/nointro.snes"
    typeset -gr SNES_FILES_XML="nointro.snes_files.xml"
    typeset -gr SNES_META_XML="nointro.snes_meta.xml"
    typeset -gr N64_URL="https://archive.org/download/nointro.n64"
    typeset -gr N64_FILES_XML="nointro.n64_files.xml"
    typeset -gr N64_META_XML="nointro.n64_meta.xml"
    typeset -gr GB_URL="https://archive.org/download/nointro.gb"
    typeset -gr GB_FILES_XML="nointro.gb_files.xml"
    typeset -gr GB_META_XML="nointro.gb_meta.xml"
    typeset -gr GBC_URL="https://archive.org/download/nointro.gbc"
    typeset -gr GBC_FILES_XML="nointro.gbc_files.xml"
    typeset -gr GBC_META_XML="nointro.gbc_meta.xml"
    typeset -gr GBA_URL="https://archive.org/download/nointro.gba"
    typeset -gr GBA_FILES_XML="nointro.gba_files.xml"
    typeset -gr GBA_META_XML="nointro.gba_meta.xml"
    typeset -gr TG16_URL="https://archive.org/download/nointro.tg-16"
    typeset -gr TG16_FILES_XML="nointro.tg-16_files.xml"
    typeset -gr TG16_META_XML="nointro.tg-16_meta.xml"
    typeset -gr TG16CD_URL="https://archive.org/download/chd_pcecd"
    typeset -gr TG16CD_FILES_XML="chd_pcecd_files.xml"
    typeset -gr TG16CD_META_XML="chd_pcecd_meta.xml"
    typeset -gr SMS_URL="https://archive.org/download/nointro.ms-mkiii"
    typeset -gr SMS_FILES_XML="nointro.ms-mkiii_files.xml"
    typeset -gr SMS_META_XML="nointro.ms-mkiii_meta.xml"
    typeset -gr GG_URL="https://archive.org/download/nointro.gg"
    typeset -gr GG_FILES_XML="nointro.gg_files.xml"
    typeset -gr GG_META_XML="nointro.gg_meta.xml"
    typeset -gr MD_URL="https://archive.org/download/nointro.md"
    typeset -gr MD_FILES_XML="nointro.md_files.xml"
    typeset -gr MD_META_XML="nointro.md_meta.xml"
    typeset -gr MCD_URL="https://archive.org/download/chd_segacd"
    typeset -gr MCD_FILES_XML="chd_segacd_files.xml"
    typeset -gr MCD_META_XML="chd_segacd_meta.xml"
    typeset -gr SS_URL="https://archive.org/download/chd_saturn"
    typeset -gr SS_FILES_XML="chd_saturn_files.xml"
    typeset -gr SS_META_XML="chd_saturn_meta.xml"
    typeset -gr PSXUS_URL="https://archive.org/download/chd_psx"
    typeset -gr PSXUS_FILES_XML="chd_psx_files.xml"
    typeset -gr PSXUS_META_XML="chd_psx_meta.xml"
    typeset -gr PSXEU_URL="https://archive.org/download/chd_psx_eur"
    typeset -gr PSXEU_FILES_XML="chd_psx_eur_files.xml"
    typeset -gr PSXEU_META_XML="chd_psx_eur_meta.xml"
    typeset -gr PSXJP_URL="https://archive.org/download/chd_psx_jap"
    typeset -gr PSXJP_FILES_XML="chd_psx_jap_files.xml"
    typeset -gr PSXJP_META_XML="chd_psx_jap_meta.xml"
    typeset -gr PSXJP2_URL="https://archive.org/download/chd_psx_jap_p2"
    typeset -gr PSXJP2_FILES_XML="chd_psx_jap_p2_files.xml"
    typeset -gr PSXJP2_META_XML="chd_psx_jap_p2_meta.xml"
    typeset -gr PSXMISC_URL="https://archive.org/download/chd_psx_misc"
    typeset -gr PSXMISC_FILES_XML="chd_psx_misc_files.xml"
    typeset -gr PSXMISC_META_XML="chd_psx_misc_meta.xml"
    typeset -gr AO486_URL="https://archive.org/download/0mhz-dos"
    typeset -gr AO486_FILES_XML="0mhz-dos_files.xml"
    typeset -gr AO486_META_XML="0mhz-dos_meta.xml"
    typeset -gr CD32_URL="https://archive.org/download/commodore-amiga-cd32-redump-collection"
    typeset -gr CD32_FILES_XML="commodore-amiga-cd32-redump-collection_files.xml"
    typeset -gr CD32_META_XML="commodore-amiga-cd32-redump-collection_meta.xml"
    typeset -gr GNW_URL="https://archive.org/download/gnw-games"
    typeset -gr GNW_FILES_XML="gnw-games_files.xml"
    typeset -gr GNW_META_XML="gnw-games_meta.xml"
    typeset -gr WS_URL="https://archive.org/download/nointro-bandai-wonderswanwonderswan-color"
    typeset -gr WS_FILES_XML="nointro-bandai-wonderswanwonderswan-color_files.xml"
    typeset -gr WS_META_XML="nointro-bandai-wonderswanwonderswan-color_meta.xml"
    typeset -gr WSC_URL="https://archive.org/download/nointro-bandai-wonderswanwonderswan-color"
    typeset -gr WSC_FILES_XML="nointro-bandai-wonderswanwonderswan-color_files.xml"
    typeset -gr WSC_META_XML="nointro-bandai-wonderswanwonderswan-color_meta.xml"
    typeset -gr PV1000_URL="https://archive.org/download/nointro-casio-loopy-pv-1000"
    typeset -gr PV1000_FILES_XML="nointro-casio-loopy-pv-1000_files.xml"
    typeset -gr PV1000_META_XML="nointro-casio-loopy-pv-1000_meta.xml"
    typeset -gr NEOGEO_URL="https://archive.org/download/neogeoaesmvscomplete"
    typeset -gr NEOGEO_FILES_XML="neogeoaesmvscomplete_files.xml"
    typeset -gr NEOGEO_META_XML="neogeoaesmvscomplete_meta.xml"
    typeset -gr NEOGEOCD_URL="https://archive.org/download/snk-neo-geo-cd-redump-collection"
    typeset -gr NEOGEOCD_FILES_XML="snk-neo-geo-cd-redump-collection_files.xml"
    typeset -gr NEOGEOCD_META_XML="snk-neo-geo-cd-redump-collection_meta.xml"
    typeset -gr TDO_URL="https://archive.org/download/3do-redump-collection"
    typeset -gr TDO_FILES_XML="3do-redump-collection_files.xml"
    typeset -gr TDO_META_XML="3do-redump-collection_meta.xml"
    typeset -gr S32X_URL="https://archive.org/download/ni-se-32x"
    typeset -gr S32X_FILES_XML="ni-se-32x_files.xml"
    typeset -gr S32X_META_XML="ni-se-32x_meta.xml"
    typeset -gr CDI_URL="https://archive.org/download/philips-cd-i-redump-collection"
    typeset -gr CDI_FILES_XML="philips-cd-i-redump-collection_files.xml"
    typeset -gr CDI_META_XML="philips-cd-i-redump-collection_meta.xml"
    typeset -gr JAG_URL="https://archive.org/download/ef_atari_jaguar_no-intro_2023-10-13"
    typeset -gr JAG_FILES_XML="ef_atari_jaguar_no-intro_2023-10-13_files.xml"
    typeset -gr JAG_META_XML="ef_atari_jaguar_no-intro_2023-10-13_meta.xml"
    typeset -gr A2600_URL="https://archive.org/download/nointro.atari-2600"
    typeset -gr A2600_FILES_XML="nointro.atari-2600_files.xml"
    typeset -gr A2600_META_XML="nointro.atari-2600_meta.xml"
    typeset -gr A5200_URL="https://archive.org/download/nointro.atari-5200"
    typeset -gr A5200_FILES_XML="nointro.atari-5200_files.xml"
    typeset -gr A5200_META_XML="nointro.atari-5200_meta.xml"
    typeset -gr A7800_URL="https://archive.org/download/atari-7800-no-intro-romset-2025-06-25"
    typeset -gr A7800_FILES_XML="atari-7800-no-intro-romset-2025-06-25_files.xml"
    typeset -gr A7800_META_XML="atari-7800-no-intro-romset-2025-06-25_meta.xml"
    typeset -gr MSX_URL="https://archive.org/download/ef_msx1_no-intro_2023-12-23"
    typeset -gr MSX_FILES_XML="ef_msx1_no-intro_2023-12-23_files.xml"
    typeset -gr MSX_META_XML="ef_msx1_no-intro_2023-12-23_meta.xml"
    typeset -gr C64_URL="https://archive.org/download/nointro.c64"
    typeset -gr C64_FILES_XML="nointro.c64_files.xml"
    typeset -gr C64_META_XML="nointro.c64_meta.xml"

    # Dialog box maximum size, leave a small border in case of overscan
    typeset -gr MAXHEIGHT=$(( $LINES - 4 ))
    typeset -gr MAXWIDTH=$(( $COLUMNS - 4 ))

    typeset -gr DIALOG_OK=0
    typeset -gr DIALOG_CANCEL=1
    typeset -gr DIALOG_HELP=2
    typeset -gr DIALOG_EXTRA=3
    typeset -gr DIALOG_ITEM_HELP=4
    typeset -gr DIALOG_ESC=255

    # Fixes ncurses output with many terminals (eg. PuTTY)
    typeset -grx NCURSES_NO_UTF8_ACS=1
    #export NCURSES_NO_UTF8_ACS

    # Common curl options
    typeset -ga CURL_OPTS=(--connect-timeout 5 --retry 3 --retry-delay 5)

    # dialog(1) writes results to a tempfile via stderr
    typeset -gr DIALOG_TEMPFILE=$(mktemp 2>/dev/null) || DIALOG_TEMPFILE=/tmp/test$$

    typeset -gr SIG_NONE=0
    typeset -gr SIG_HUP=1
    typeset -gr SIG_INT=2
    typeset -gr SIG_QUIT=3
    typeset -gr SIG_KILL=9
    typeset -gr SIG_TERM=15
}

# User configurable options
set_conf_opts () {
    typeset -gr NES_GAMEDIR=${NES_GAMEDIR:-/media/fat/games/NES}
    typeset -gr SNES_GAMEDIR=${SNES_GAMEDIR:-/media/fat/games/SNES}
    typeset -gr N64_GAMEDIR=${N64_GAMEDIR:-/media/fat/games/N64}
    typeset -gr GB_GAMEDIR=${GB_GAMEDIR:-/media/fat/games/GAMEBOY}
    typeset -gr GBC_GAMEDIR=${GBC_GAMEDIR:-/media/fat/games/GAMEBOY}
    typeset -gr GBA_GAMEDIR=${GBA_GAMEDIR:-/media/fat/games/GBA}
    typeset -gr TG16_GAMEDIR=${TG16_GAMEDIR:-/media/fat/games/TGFX16}
    typeset -gr TG16CD_GAMEDIR=${TG16CD_GAMEDIR:-/media/fat/games/TGFX16-CD}
    typeset -gr SMS_GAMEDIR=${SMS_GAMEDIR:-/media/fat/games/SMS}
    typeset -gr GG_GAMEDIR=${GG_GAMEDIR:-/media/fat/games/SMS}
    typeset -gr MD_GAMEDIR=${MD_GAMEDIR:-/media/fat/games/MegaDrive}
    typeset -gr MCD_GAMEDIR=${MCD_GAMEDIR:-/media/fat/games/MegaCD}
    typeset -gr SS_GAMEDIR=${SS_GAMEDIR:-/media/fat/games/Saturn}
    typeset -gr PSXUS_GAMEDIR=${PSXUS_GAMEDIR:-/media/fat/games/PSX}
    typeset -gr PSXEU_GAMEDIR=${PSXEU_GAMEDIR:-/media/fat/games/PSX}
    typeset -gr PSXJP_GAMEDIR=${PSXJP_GAMEDIR:-/media/fat/games/PSX}
    typeset -gr PSXJP2_GAMEDIR=${PSXJP2_GAMEDIR:-/media/fat/games/PSX}
    typeset -gr PSXMISC_GAMEDIR=${PSXMISC_GAMEDIR:-/media/fat/games/PSX}
    # The 0MHz DOS zips have required directory structure builtin (smart!)
    typeset -gr AO486_GAMEDIR=${AO486_GAMEDIR:-/media/fat}
    typeset -gr CD32_GAMEDIR=${CD32_GAMEDIR:-/media/fat/games/AmigaCD32}
    typeset -gr GNW_GAMEDIR=${GNW_GAMEDIR:-/media/fat/games/GameNWatch}
    typeset -gr WS_GAMEDIR=${WS_GAMEDIR:-/media/fat/games/WonderSwan}
    typeset -gr WSC_GAMEDIR=${WSC_GAMEDIR:-/media/fat/games/WonderSwanColor}
    typeset -gr PV1000_GAMEDIR=${PV1000_GAMEDIR:-/media/fat/games/Casio_PV-1000}
    typeset -gr NEOGEO_GAMEDIR=${NEOGEO_GAMEDIR:-/media/fat/games/NeoGeo}
    typeset -gr NEOGEOCD_GAMEDIR=${NEOGEOCD_GAMEDIR:-/media/fat/games/NeoGeo-CD}
    typeset -gr TDO_GAMEDIR=${TDO_GAMEDIR:-/media/fat/games/3DO}
    typeset -gr S32X_GAMEDIR=${S32X_GAMEDIR:-/media/fat/games/S32X}
    typeset -gr CDI_GAMEDIR=${CDI_GAMEDIR:-/media/fat/games/CD-i}
    typeset -gr JAG_GAMEDIR=${JAG_GAMEDIR:-/media/fat/games/Jaguar}
    typeset -gr A2600_GAMEDIR=${A2600_GAMEDIR:-/media/fat/games/ATARI2600}
    typeset -gr A5200_GAMEDIR=${A5200_GAMEDIR:-/media/fat/games/ATARI5200}
    typeset -gr A7800_GAMEDIR=${A7800_GAMEDIR:-/media/fat/games/ATARI7800}
    typeset -gr MSX_GAMEDIR=${MSX_GAMEDIR:-/media/fat/games/MSX}
    typeset -gr C64_GAMEDIR=${C64_GAMEDIR:-/media/fat/games/C64}
    # Simplified mode for use without a keyboard (true/false toggle)
    typeset -g JOY_MODE=${JOY_MODE:-false}
    # Max concurrent background downloads (1..5, default 3)
    typeset -g MAX_CONCURRENT_DOWNLOADS=${MAX_CONCURRENT_DOWNLOADS:-3}
    (( MAX_CONCURRENT_DOWNLOADS < 1 )) && MAX_CONCURRENT_DOWNLOADS=1
    (( MAX_CONCURRENT_DOWNLOADS > 5 )) && MAX_CONCURRENT_DOWNLOADS=5
}

# Dynamically set environment variables to point to currently selected repository
select_core () {
    typeset -g CORE=${1}
    typeset -g CORE_URL=${(P)${:-${CORE}_URL}}
    typeset -g CORE_GAMEDIR=${(P)${:-${CORE}_GAMEDIR}}
    typeset -g CORE_FILES_XML=${(P)${:-${CORE}_FILES_XML}}
    typeset -g CORE_META_XML=${(P)${:-${CORE}_META_XML}}
}

get_config () {
    typeset -g TITLE=${ROMWEASEL_VERSION}
    if [[ -f ${SETTINGS_SH} ]]; then
        local t=$(source ${SETTINGS_SH} 2>&1)
        [[ -n $t ]] && { print "Error parsing user configuration file: $t" ; cleanup }
        source ${SETTINGS_SH}
        set_conf_opts ; return
    fi

    # If configuration ddfile doesn't exist, create one from scratch
    set_conf_opts
    tmpl=("# Automatically generated romweasel configuration template\n")
    tmpl+="# Root directories per core / ROM repository"
    for (( i=1; i<${#SUPPORTED_CORES}; i+=2 )) ; do
        tmpl+="#${SUPPORTED_CORES[i]}_GAMEDIR=\"${(P)${:-${SUPPORTED_CORES[i]}_GAMEDIR}}\""
    done
    tmpl+="\n# Simplified mode for use without a keyboard (true/false)"
    tmpl+="#JOY_MODE=false"
    print -l $tmpl > ${SETTINGS_SH}
    unset tmpl i
}

# Helper functions, fetch metadata from XML based on tag name (always same as full path filename)
get_tag_filename () {
    local tag="${1}"
    # This should always just return same as input was
    print $($XMLLINT ${CORE_FILES_XML} --xpath "string(files/file[@name=\""$tag"\"]/@name)")
}
get_tag_filesize () {
    local tag="${1}"
    local human_readable=${2:-false}
    local res=$($XMLLINT ${CORE_FILES_XML} --xpath "string(files/file[@name=\""$tag"\"]/size)")
    $human_readable && print $(humanise $res) || print $res
}
get_tag_sha1sum () {
    local tag="${1}"
    print $($XMLLINT ${CORE_FILES_XML} --xpath "string(files/file[@name=\""$tag"\"]/sha1)")
}

# Convert input bytes into more human-readable form
humanise () { print $(${NUMFMT} --to=iec-i --suffix=B --format="%9.2f" ${1}) }

# URL encode a string, including parenthesis but not a slash
urlencode () {
    local input=(${(s::)1})
    # Set by backreference glob (#b), and since they get set for each character to
    # encode, option WARN_NESTED_VAR will complain loudly if they're not declared local.
    local match mbegin mend
    print ${(j::)input/(#b)([^A-Za-z0-9_.!~*\-\/])/%${(l:2::0:)$(([##16]#match))}}
}

cleanup () {
    [[ -f $DIALOG_TEMPFILE ]] && rm $DIALOG_TEMPFILE
    queue_kill_background
    [[ -f cookie.tmp ]] && rm cookie.tmp
    [[ $(ls -A $CACHE_DIR) ]] && print "Warning: cache dir $CACHE_DIR not empty"
    exit 0
}

#################################################################
# Download queue — background workers, max N concurrent, user
# can pause/resume/cancel/launch individual items from the queue
# view. State files under $WRK_DIR/queue/ so the queue survives
# script restart (interrupted downloads re-queue as 'queued' and
# wget -c resumes from the partial file).
#################################################################

queue_dir () { print "${WRK_DIR}/queue" }

queue_ensure_dir () {
    local qd=$(queue_dir)
    [[ -d $qd ]] || mkdir -p $qd
    print $qd
}

# Set of status constants — stored as plain text in $itemdir/status
# queued:    waiting for a worker slot
# running:   wget in flight
# paused:    SIGSTOP'd worker (partial file preserved)
# done:      transferred and installed into game dir
# failed:    download or checksum failed
# cancelled: user aborted, partial file removed

# Enqueue an array of ROM tags for the currently selected core.
# Creates one item dir per tag under $WRK_DIR/queue/<ts>_<slug>/
# and spawns the dispatcher if not already running.
queue_enqueue () {
    local -a tags=($@)
    local qd=$(queue_ensure_dir)
    local tag size sha1 filename slug ts itemdir i=0
    for tag in $tags; do
        (( i++ ))
        size=$(get_tag_filesize "$tag")
        sha1=$(get_tag_sha1sum "$tag")
        filename=$(get_tag_filename "$tag")
        # Unique ordered id: epoch seconds + counter + sanitized name
        ts=$(date +%s)
        slug=${${tag##*/}%.(7z|zip|chd)}
        slug=${slug//[^A-Za-z0-9._-]/_}
        slug=${slug:0:48}
        itemdir="${qd}/${ts}_${i}_${slug}"
        mkdir -p $itemdir
        # Shell-sourceable meta, avoids embedded newlines in tag
        {
            print "TAG=\"${tag}\""
            print "FILENAME=\"${filename}\""
            print "CORE=\"${CORE}\""
            print "CORE_URL=\"${CORE_URL}\""
            print "CORE_FILES_XML=\"${CORE_FILES_XML}\""
            print "DEST_DIR=\"${CORE_GAMEDIR}\""
            print "SIZE=\"${size}\""
            print "SHA1=\"${sha1}\""
            print "ADDED_AT=\"${ts}\""
        } > $itemdir/meta
        print queued > $itemdir/status
        print 0 > $itemdir/progress
    done
    queue_spawn_dispatcher
}

# Spawn the dispatcher as a detached background process if not
# already running. Dispatcher uses flock to guarantee singleton.
queue_spawn_dispatcher () {
    local qd=$(queue_ensure_dir)
    print ${MAX_CONCURRENT_DOWNLOADS} > ${qd}/.max_concurrent
    if [[ -f ${qd}/.dispatcher.pid ]]; then
        local pid=$(<${qd}/.dispatcher.pid)
        if kill -0 $pid 2>/dev/null; then
            return 0
        fi
    fi
    setsid zsh $ROMWEASEL_SELF --dispatcher </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null || true
}

# Count queue items by status
queue_counts () {
    local qd=$(queue_dir)
    [[ -d $qd ]] || { print "0 0 0 0 0 0" ; return }
    local q r p d f c
    q=0 r=0 p=0 d=0 f=0 c=0
    local item st
    for item in ${qd}/*(N/); do
        [[ -f ${item}/status ]] || continue
        st=$(<${item}/status)
        case $st in
            queued)    (( q++ )) ;;
            running)   (( r++ )) ;;
            paused)    (( p++ )) ;;
            done)      (( d++ )) ;;
            failed)    (( f++ )) ;;
            cancelled) (( c++ )) ;;
        esac
    done
    print "$q $r $p $d $f $c"
}

queue_total () {
    local counts=($(queue_counts))
    print $(( counts[1] + counts[2] + counts[3] + counts[4] + counts[5] + counts[6] ))
}

# Kill dispatcher + all workers, mark in-progress items as queued
# so they resume on next launch. Called from cleanup().
queue_kill_background () {
    local qd=$(queue_dir)
    [[ -d $qd ]] || return 0
    # Kill dispatcher
    if [[ -f ${qd}/.dispatcher.pid ]]; then
        local dpid=$(<${qd}/.dispatcher.pid)
        kill -TERM $dpid 2>/dev/null
    fi
    # Kill workers and re-queue
    local item wpid st
    for item in ${qd}/*(N/); do
        [[ -f ${item}/worker.pid ]] || continue
        wpid=$(<${item}/worker.pid)
        kill -TERM $wpid 2>/dev/null
        rm -f ${item}/worker.pid
        [[ -f ${item}/status ]] || continue
        st=$(<${item}/status)
        if [[ $st == "running" || $st == "paused" ]]; then
            print queued > ${item}/status
        fi
    done
    # Small grace period then SIGKILL any stragglers
    sleep 0.3
    if [[ -f ${qd}/.dispatcher.pid ]]; then
        kill -KILL $(<${qd}/.dispatcher.pid) 2>/dev/null
        rm -f ${qd}/.dispatcher.pid
    fi
}

# Dispatcher loop — invoked via `romweasel.sh --dispatcher`.
# Drains queued items, respecting MAX_CONCURRENT_DOWNLOADS, by
# spawning per-item worker subprocesses. Exits when nothing left
# to do. Singleton-enforced via flock.
queue_dispatcher_loop () {
    local qd=$(queue_dir)
    [[ -d $qd ]] || exit 0
    exec 9>${qd}/.dispatcher.lock
    flock -n 9 || exit 0
    print $$ > ${qd}/.dispatcher.pid
    trap 'rm -f ${qd}/.dispatcher.pid; exit 0' EXIT TERM INT

    local max running next_dir item st any_work
    while true; do
        # Refresh max from file (allows live updates)
        if [[ -f ${qd}/.max_concurrent ]]; then
            max=$(<${qd}/.max_concurrent)
        else
            max=3
        fi
        (( max < 1 )) && max=1
        (( max > 5 )) && max=5

        # Count running workers; reconcile dead workers
        running=0
        for item in ${qd}/*(N/); do
            [[ -f ${item}/status ]] || continue
            st=$(<${item}/status)
            if [[ $st == "running" ]]; then
                if [[ -f ${item}/worker.pid ]] && kill -0 $(<${item}/worker.pid) 2>/dev/null; then
                    (( running++ ))
                else
                    # Worker died without updating status — mark failed
                    print failed > ${item}/status
                    rm -f ${item}/worker.pid
                fi
            fi
        done

        # Fill empty slots
        while (( running < max )); do
            next_dir=""
            for item in ${qd}/*(N/); do
                [[ -f ${item}/status ]] || continue
                if [[ $(<${item}/status) == "queued" ]]; then
                    next_dir=$item
                    break
                fi
            done
            [[ -z $next_dir ]] && break
            print running > ${next_dir}/status
            setsid zsh $ROMWEASEL_SELF --worker "$next_dir" </dev/null >/dev/null 2>&1 &
            disown 2>/dev/null || true
            (( running++ ))
            sleep 0.2
        done

        # Exit if nothing active and nothing queued
        any_work=false
        for item in ${qd}/*(N/); do
            [[ -f ${item}/status ]] || continue
            st=$(<${item}/status)
            if [[ $st == "queued" || $st == "running" ]]; then
                any_work=true
                break
            fi
        done
        $any_work || break

        sleep 2
    done
    rm -f ${qd}/.dispatcher.pid
}

# Worker body — invoked via `romweasel.sh --worker <itemdir>`.
# Downloads meta.URL to meta.DEST_DIR, verifies SHA1, extracts if
# compressed, and updates status. Partial file at $itemdir/download.part
# allows SIGTERM recovery via wget -c on next run.
queue_worker_run () {
    local itemdir=$1
    [[ -d $itemdir ]] || exit 1
    [[ -f ${itemdir}/meta ]] || exit 1

    source ${itemdir}/meta
    print $$ > ${itemdir}/worker.pid

    local tmpfile="${itemdir}/download.part"
    local url="${CORE_URL}/$(urlencode "${FILENAME}")"
    local cookiejar="${WRK_DIR}/cookie.tmp"
    local wget_args=(-c --read-timeout=60 --tries=20 --waitretry=5
                     --connect-timeout=15 -O "$tmpfile" "$url")
    [[ -f $cookiejar ]] && wget_args=(--load-cookies "$cookiejar" $wget_args)

    trap '
        [[ -f ${itemdir}/status ]] && [[ $(<${itemdir}/status) == "running" ]] \
            && print queued > ${itemdir}/status
        rm -f ${itemdir}/worker.pid
        exit 130
    ' TERM INT

    # Launch wget, poll progress in this shell
    wget $wget_args 2>>${itemdir}/worker.log &
    local wget_pid=$!
    while kill -0 $wget_pid 2>/dev/null; do
        if [[ -f $tmpfile ]]; then
            stat -c %s "$tmpfile" > ${itemdir}/progress 2>/dev/null
        fi
        sleep 1
    done
    wait $wget_pid
    local rc=$?

    if [[ $rc -ne 0 ]]; then
        print failed > ${itemdir}/status
        rm -f ${itemdir}/worker.pid
        exit $rc
    fi

    # Verify checksum
    local filesum=${${(z):-$($SHA1SUM "$tmpfile")}[1]}
    if [[ -n $SHA1 && "$filesum" != "$SHA1" ]]; then
        print "ERROR: checksum mismatch got=$filesum want=$SHA1" >> ${itemdir}/worker.log
        print failed > ${itemdir}/status
        rm -f ${itemdir}/worker.pid
        exit 1
    fi

    # Install to dest dir
    [[ -d "$DEST_DIR" ]] || mkdir -p "$DEST_DIR"
    local basefile=${FILENAME##*/}
    if [[ -z ${basefile##*.7z} ]]; then
        $SZR e "$tmpfile" -o"$DEST_DIR" -y >>${itemdir}/worker.log 2>&1
        rm -f "$tmpfile"
    elif [[ -z ${basefile##*.zip} ]]; then
        $UNZIP -o -qq -d "$DEST_DIR" "$tmpfile" >>${itemdir}/worker.log 2>&1
        rm -f "$tmpfile"
    else
        mv "$tmpfile" "${DEST_DIR}/${basefile}"
    fi

    print done > ${itemdir}/status
    rm -f ${itemdir}/worker.pid
}

# Dialog-based queue browser. Select an item to act on it.
queue_view () {
    local qd=$(queue_dir)
    while true; do
        local -a menu_args items
        menu_args=()
        items=()
        local item st prog pct name core_name size_mb label icon

        for item in ${qd}/*(N/); do
            [[ -f ${item}/meta ]] || continue
            [[ -f ${item}/status ]] || continue
            st=$(<${item}/status)
            prog=0
            [[ -f ${item}/progress ]] && prog=$(<${item}/progress)
            source ${item}/meta
            pct=0
            (( SIZE > 0 )) && pct=$(( prog * 100 / SIZE ))
            (( pct > 100 )) && pct=100
            size_mb=$(( SIZE / 1048576 ))
            name=${FILENAME##*/}
            name=${name%.(7z|zip|chd)}
            case $st in
                queued)    icon="WAIT " ;;
                running)   icon="DL ${pct}%" ;;
                paused)    icon="PAUSE" ;;
                done)      icon="DONE " ;;
                failed)    icon="FAIL " ;;
                cancelled) icon="CANCL" ;;
                *)         icon="?????" ;;
            esac
            label="[${icon}] ${CORE} ${name} (${size_mb}M)"
            items+=("${item}")
            menu_args+=("${item}" "${label:0:$(( MAXWIDTH - 10 ))}")
        done

        if (( ${#items} == 0 )); then
            $DIALOG --title "Download Queue" --msgbox \
                "Queue is empty.\n\nStart a download to populate it." 8 50
            return
        fi

        $DIALOG --clear --title "Download Queue (max ${MAX_CONCURRENT_DOWNLOADS} concurrent)" \
            --extra-button --extra-label "Refresh" \
            --help-button --help-label "Settings" \
            --cancel-label "Back" --ok-label "Manage" \
            --menu "Select item to manage:" \
            $MAXHEIGHT $MAXWIDTH $#items \
            $menu_args 2>$DIALOG_TEMPFILE
        local rc=$?
        case $rc in
            $DIALOG_OK)
                queue_item_menu "$(<$DIALOG_TEMPFILE)"
                ;;
            $DIALOG_EXTRA)
                continue
                ;;
            $DIALOG_HELP)
                queue_settings_menu
                ;;
            *)
                return
                ;;
        esac
    done
}

# Actions for a single queue item
queue_item_menu () {
    local itemdir=$1
    [[ -d $itemdir && -f ${itemdir}/meta ]] || return
    source ${itemdir}/meta
    local st=$(<${itemdir}/status)
    local name=${FILENAME##*/}

    local -a actions=()
    case $st in
        queued)
            actions+=(cancel "Remove from queue")
            ;;
        running)
            actions+=(pause "Pause")
            actions+=(cancel "Cancel and discard partial")
            ;;
        paused)
            actions+=(resume "Resume")
            actions+=(cancel "Cancel and discard partial")
            ;;
        done)
            actions+=(launch "Launch game now")
            actions+=(remove "Remove from queue list")
            ;;
        failed|cancelled)
            actions+=(retry "Retry download")
            actions+=(remove "Remove from queue list")
            ;;
    esac
    actions+=(log "View worker log")
    actions+=(back "Back")

    $DIALOG --clear --title "${name}" \
        --menu "Status: ${st}\nCore: ${CORE}\nSize: $(( SIZE / 1048576 )) MB" \
        16 72 8 $actions 2>$DIALOG_TEMPFILE
    [[ $? -ne $DIALOG_OK ]] && return
    local action=$(<$DIALOG_TEMPFILE)

    case $action in
        pause)
            [[ -f ${itemdir}/worker.pid ]] && kill -STOP $(<${itemdir}/worker.pid) 2>/dev/null
            print paused > ${itemdir}/status
            ;;
        resume)
            [[ -f ${itemdir}/worker.pid ]] && kill -CONT $(<${itemdir}/worker.pid) 2>/dev/null
            print running > ${itemdir}/status
            ;;
        cancel)
            if [[ -f ${itemdir}/worker.pid ]]; then
                kill -CONT $(<${itemdir}/worker.pid) 2>/dev/null
                kill -TERM $(<${itemdir}/worker.pid) 2>/dev/null
            fi
            print cancelled > ${itemdir}/status
            rm -f ${itemdir}/download.part ${itemdir}/worker.pid
            queue_spawn_dispatcher
            ;;
        retry)
            print queued > ${itemdir}/status
            print 0 > ${itemdir}/progress
            rm -f ${itemdir}/worker.log
            queue_spawn_dispatcher
            ;;
        remove)
            if [[ -f ${itemdir}/worker.pid ]]; then
                kill -CONT $(<${itemdir}/worker.pid) 2>/dev/null
                kill -TERM $(<${itemdir}/worker.pid) 2>/dev/null
            fi
            rm -rf $itemdir
            ;;
        launch)
            local target="${DEST_DIR}/${FILENAME##*/}"
            # For compressed files the base name differs — do a best-effort glob
            if [[ ! -f $target ]]; then
                local hits=(${DEST_DIR}/${${FILENAME##*/}%.(7z|zip|chd)}*(N))
                [[ -n $hits ]] && target=$hits[1]
            fi
            if [[ -f $target ]]; then
                if [[ -x /media/fat/Scripts/zaparoo.sh ]]; then
                    /media/fat/Scripts/zaparoo.sh -run "$target" >/dev/null 2>&1 &
                else
                    print "load_core $target" > /dev/MiSTer_cmd 2>/dev/null
                fi
                sleep 1
                exit 0
            else
                $DIALOG --msgbox "File not found on disk:\n$target" 7 70
            fi
            ;;
        log)
            if [[ -f ${itemdir}/worker.log ]]; then
                $DIALOG --title "Worker log" --textbox ${itemdir}/worker.log \
                    $MAXHEIGHT $MAXWIDTH
            else
                $DIALOG --msgbox "No log available." 5 40
            fi
            ;;
    esac
}

queue_settings_menu () {
    local choice
    $DIALOG --title "Queue settings" \
        --menu "Max concurrent downloads (1..5):" 12 50 5 \
        1 "1 download at a time" \
        2 "2 concurrent" \
        3 "3 concurrent (default)" \
        4 "4 concurrent" \
        5 "5 concurrent (max)" \
        2>$DIALOG_TEMPFILE
    [[ $? -ne $DIALOG_OK ]] && return
    choice=$(<$DIALOG_TEMPFILE)
    MAX_CONCURRENT_DOWNLOADS=$choice
    print $choice > $(queue_dir)/.max_concurrent
    queue_spawn_dispatcher
}

# Login to archive.org and setup a cookie for all downloads, if IA_USER/IA_PASS
# variables are set. Uses the xauthn API (services/xauthn/) which returns a JSON
# payload with session cookies and S3 keys. The older form-post to /account/login
# stopped returning JSON and started returning the HTML login page, so the old
# flow's `jq '.status == "ok"'` check always failed.
ia_login () {
    # Variables are sourced from ~/.profile by other scripts as well
    if [[ -f ~/.profile ]]; then source ~/.profile; fi
    if [[ -z $IA_USER ]] || [[ -z $IA_PASS ]]; then return; fi

    local resp
    resp=$($CURL $CURL_OPTS -sk -X POST 'https://archive.org/services/xauthn/?op=login' \
        --data-urlencode "email=$IA_USER" \
        --data-urlencode "password=$IA_PASS" \
        --data-urlencode 'version=1' 2>/dev/null)

    if ! print -- "$resp" | $JQ -er '.success' >/dev/null 2>&1; then
        $DIALOG --title $TITLE \
            --msgbox "Error logging in to archive.org. Please check IA_USER / IA_PASS variables." 5 78
        cleanup
    fi

    local sig user
    sig=$(print -- "$resp"  | $JQ -r '.values.cookies["logged-in-sig"]'  | cut -d';' -f1)
    user=$(print -- "$resp" | $JQ -r '.values.cookies["logged-in-user"]' | cut -d';' -f1)

    # Write a Netscape-format cookie jar that curl can read with -b/-c.
    {
        print "# Netscape HTTP Cookie File"
        print ".archive.org\tTRUE\t/\tTRUE\t2147483647\tlogged-in-sig\t${sig}"
        print ".archive.org\tTRUE\t/\tFALSE\t2147483647\tlogged-in-user\t${user}"
    } > cookie.tmp

    unsetopt warnnestedvar
    CURL_OPTS+=(-c cookie.tmp -b cookie.tmp)
    setopt warnnestedvar
}

# Download XML files containing all ROM metadata
fetch_metadata () {
    # If any XML files already exist, ask the user if forced re-download is desired.
    #
    # A technically more correct method would be always re-downloading only when remote file
    # has a newer timestamp than the local (which is trivially doable), but this approach is
    # in practice just as slow as unconditionally re-downloading all of the files.
    local -a xmls=($(print *.xml(N)))
    if [[ -n $xmls ]]; then
        $DIALOG --title $TITLE --defaultno \
            --yesno "Do you want to re-download ROM repository metadata?" 5 58
        [[ $? -eq $DIALOG_OK ]] && rm $xmls
    fi

    local -i i
    # Loop through the list of ROM repositories
    (for (( i=1; i<${#SUPPORTED_CORES}; i+=2 )) ; do
        # Print some calming statistics via dialog gauge widget while downloading
        printf "%s\n" "XXX"
        printf "%i\n" $(( 100.0 / ${#SUPPORTED_CORES} * $i ))
        printf "%s\n\n" "Downloading ROM repository metadata XML files"
        printf "%s\n" "Currently downloading $(((${i}+1)/2)) of $((${#SUPPORTED_CORES}/2)):"
        printf "%s\n" "${SUPPORTED_CORES[$(($i+1))]}"
        printf "%s\n" "XXX"
        select_core ${SUPPORTED_CORES[i]}
        [[ -f ${CORE_FILES_XML} ]] || $CURL $CURL_OPTS -skLO ${CORE_URL}/${CORE_FILES_XML}
        [[ -f ${CORE_META_XML} ]] || $CURL $CURL_OPTS -skLO ${CORE_URL}/${CORE_META_XML}
    done) |\
        $DIALOG --title $TITLE --gauge \
            "Downloading ROM repository metadata XML files (total: $((${#SUPPORTED_CORES}/2)))" \
            16 $(($MAXWIDTH / 2)) 0

    [[ $? -ne $DIALOG_OK ]] && cleanup
}

# Display information for selected ROMs
get_rom_info () {
    local -a tags=($*)
    local rominfo="" totalsize=0 romsize file_name tag dest
    for tag in $tags; do
        romsize=$(get_tag_filesize "$tag")
        # MiSTer Zsh is compiled with only 4-byte integers, so shell
        # arithmetic is unfit to keep count of the total size
        totalsize=$(print "$totalsize + $romsize" | ${BC})
        file_name="$(get_tag_filename "$tag")"
        rominfo+="File name: ${file_name##*/}\n"
        rominfo+="File size: $(humanise $romsize)\n"
        dest="$(get_rom_gamedir "$tag")"
        if [[ $? -ne 0 ]]; then
            rominfo+="\\\Zb\\\ZrSave path\\\Zn: \\\Z4${dest}\\\Zn\n\n"
        else rominfo+="Save path: ${dest}\n\n"
        fi

    done
    rominfo+="\nTotal size: $(humanise $totalsize)\n"
    print $rominfo
}

# Get destination directory path for a given tag
get_rom_gamedir () {
    local tag=$*
    local odir="${CORE_GAMEDIR}/"
    local match mbegin mend # Set by backreference glob (#b)

    # For compressed files, it's always just the core main ROM directory
    [[ -z ${tag##*.7z} || $CORE == "AO486" ]] && { print "$odir" ; return }

    # Strip prefix subdir and file extension
    tag=${${(Q)tag%.chd}##*/}

    # MegaCD and Saturn have additional region specific subdirectories
    if [[ $CORE = "MCD" || $CORE = "SS" ]]; then
        : ${tag/(#b)\((Europe|Japan|USA)\)}
        # If we can't deduce region, well just skip it
        [[ -z $match ]] || odir+="${match}/"
    fi

    # If this isn't a multi-CD game, just use the game base name
    local base="${tag% \(Disc [0-9AB]\)*}"
    (( $#base == $#tag )) && { print "${odir}${base}/" ; return }

    # Search XML for games with same base name
    local filter="$base"
    tmpdata=$($XMLLINT $CORE_FILES_XML --xpath "files/file[sha1][contains(translate(\
        @name, \"${(U)filter}\", \"${(L)filter}\"), \"${(L)filter}\")]/@name")

    local -a ntags=(${${${${${${(@f)tmpdata}#*\"}%\"*}##*/}:#^*.chd}//\&amp\;/&})
    unset tmpdata ; local nbase
    nbase=$(find_basename "$tag" $ntags)
    if [[ $? -eq 0 ]] && { print "${odir}${nbase}/" ; return }

    # Failure
    print $odir ; return 1
}

ao486_append_setname () {
    local mgl="$*"
    local game=${mgl:t:r}

    # Use the VHD filename as setname
    local setname=$(xmllint <(sed -e 's/\&\([^\amp;]\)/\&amp;\1/g' $mgl) \
                    --xpath "string(/mistergamedescription/file/@path)")

    # Setname value has 32 character limit. This will invariably lead to some
    # name collisions, but it's still preferable to the added complexity from
    # any solution which guarantees unique names (checksums, etc.)
    setname="AO486 ${${${setname:t}%%\.*}[1,26]}"

    # Ensure <setname> element doesn't already exist
    xmllint <(sed -e 's/\&\([^\amp;]\)/\&amp;\1/g' $mgl) \
        --xpath "/mistergamedescription/setname" &>/dev/null
    if (( $? == 0 )); then
        #print "Element <setname> already set for game: $game"
        return
    fi

    local tmpf=$(mktemp)
    awk '/<\/mistergamedescription>/{print "    <setname same_dir=\"1\">'$setname'<\/setname>"}1' \
        $mgl > $tmpf
    cat $tmpf > $mgl
    rm $tmpf

    # Copy base AO486 configurations for the new setname (except keybindings)
    pushd /media/fat/config
    cp -n AO486.CFG ${setname}.CFG
    noglob zmv -W -C AO486_*.cfg ${setname}_*.cfg 2>/dev/null
    popd

    print "Created unique <setname> for game: $game"
}

# Append <setname> elements to all 0MHz DOS collection games
ao486_setnames_all () {
    local -a mgls=("/media/fat/_DOS Games"/*.mgl)

    print "${#mgls} games found, processing.."

    local mgl
    for mgl in $mgls; do
        ao486_append_setname $mgl
    done
    print "Done!"
}

# Download selected ROMs — enqueues into the background download
# queue (max ${MAX_CONCURRENT_DOWNLOADS} concurrent, default 3) and
# returns to the menu immediately. Progress, pause/resume, cancel,
# and launch-after-download are available from the [Queue] entry on
# the main menu.
download_roms () {
    local -a tags=(${*})
    local rominfo="$(get_rom_info $tags)"
    rominfo+="\nEnqueue ${#tags} item(s) for background download?\n"
    rominfo+="Progress and controls: main menu -> [Queue]\n"

    $DIALOG --title "Confirm enqueue" --clear --cr-wrap --colors \
        --yesno "$rominfo" $(( $MAXHEIGHT / 2 )) $MAXWIDTH 2>$DIALOG_TEMPFILE
    local retval=$?
    [[ $retval -eq $DIALOG_CANCEL ]] && return
    [[ $retval -ne $DIALOG_OK ]] && cleanup

    # Make sure target directory exists or if user wants it to be created
    if [[ ! -d $CORE_GAMEDIR ]]; then
        $DIALOG --title "Warning" --clear --cr-wrap --yesno \
            "Directory \"$CORE_GAMEDIR\" doesn't exist.\n\nCreate it?" \
            10 82 2>$DIALOG_TEMPFILE
        retval=$?
        [[ $retval -eq $DIALOG_CANCEL ]] && return
        [[ $retval -ne $DIALOG_OK ]] && cleanup
        mkdir -p $CORE_GAMEDIR
    fi

    # Enqueue all selected tags and return to menu
    queue_enqueue $tags
    $DIALOG --title "Queued" --msgbox \
        "${#tags} item(s) added to the download queue.\n\nReturn to the main menu and open [Queue] to monitor." \
        9 60 2>$DIALOG_TEMPFILE
    return
}

# Legacy synchronous download path — no longer invoked by the TUI
# but retained in case a future feature wants inline behaviour.
download_roms_inline () {
    local -a tags=(${*})
    local tag url ofile
    # In case the file exists already, cURL will attempt to continue the download
    local cl=(-C - -kL)

    for tag in $tags; do
        # Confirm final destination directory
        local dest=$(get_rom_gamedir $tag)
        [[ -n $dest ]] && { [[ -d $dest ]] || mkdir -p "$dest" }

        # Encoded URL to fetch from
        url="${CORE_URL}/$(urlencode "$(get_tag_filename "$tag")")"
        # Destination file with full path
        ofile="${CACHE_DIR}/${tag##*/}"
        # Download the file
        $CURL $CURL_OPTS $cl "$url" -o "$ofile"

        # Verify file checksum
        local filesum="${${(z):-$($SHA1SUM "$ofile")}[1]}"
        local metasum="$(get_tag_sha1sum "$tag")"
        if [[ $filesum = $metasum ]]; then
            print "Downloaded file checksum verified successfully!"
        else
            print "ERROR: Checksum mismatch!"
            print "Downloaded file checksum:  $filesum"
            print "Metadata claimed checksum: $metasum"
            cleanup
        fi

        # If the file is compressed, extract it, otherwise just move to destination
        print "Extracting/moving '$tag' to $dest"
        if [[ -z ${tag##*.7z} ]]; then
            $SZR e "$ofile" -o"$dest" -y
            rm "$ofile"
        elif [[ -z ${tag##*.zip} ]]; then
            $UNZIP -o -qq -d "$dest" "$ofile"

            # Append unique setname tag for 0MHz DOS collection games, so they
            # get individual config files and can retain game-specific
            # keymappings, etc. Current AO486_*.cfg files are copied for the new
            # basename, so settings like video filters are retained.
            if [[ ${CORE[1,5]} = "AO486" ]]; then
                local mgl=$CORE_GAMEDIR/$($UNZIP -l "$ofile" | grep -o '_DOS Games/.*\.mgl$')
                ao486_append_setname "$mgl"
            fi
            rm "$ofile"
        else
            mv "$ofile" "$dest"
        fi
    done

    $DIALOG --title $TITLE --cr-wrap --msgbox "Download complete!\n\nPress OK to return." \
        12 32 2>$DIALOG_TEMPFILE
    [[ $? -ne $DIALOG_OK ]] && cleanup
}

# Organise ROM files in directory $* as we would when downloading
organise_chd_dir () {
    local gamedir="${*%/}"
    local tag base nbase
    [[ -d $gamedir ]] || { print "ERROR: $gamedir is not a directory?" ; return 1 }

    local -a tags=(${gamedir}/*.chd)
    for (( i=1; i <= $#tags; i++ )) ; do
        tag="${${(Q)tags[i]%.chd}##*/}"
        base="${tag% \(Disc [0-9AB]\)*}"
        if (( $#base == $#tag )); then # Not multi-CD game
            print "\e[33m${tags[i]##*/}\e[0m -> \e[34m${base}\e[0m/"
            [[ -d "${gamedir}/${base}" ]] || mkdir "${gamedir}/${base}"
            mv "${tags[i]}" "${gamedir}/${base}"
            continue
        fi

        # Find other files with same basename and send off to neural network quantum AI
        local -a ntags=(${(M)${${(@f)tags%.chd}##*/}:#${base}*})
        nbase=$(find_basename "$tag" $ntags)
        if [[ $? -eq 0 ]]; then
            print "\e[33m${${tags[i]}##*/}\e[0m -> \e[36m${nbase}\e[0m/"
            [[ -d "${gamedir}/${nbase}" ]] || mkdir "${gamedir}/${nbase}"
            mv "${tags[i]}" "${gamedir}/${nbase}"
        else
            print "\e[35m${${tags[i]}##*/}\e[0m -> \e[31mFAILED TO COMPUTE SUITABLE NAME\e[0m"
        fi
    done
}

# Find suitable game directory name when multiple base names are identical
find_basename () {
    local tag=${(Q)1##*/}
    local -a ntags=(${(Q)@[2,-1]##*/})
    local s subdir ntag match mbegin mend
    local base=${tag//(#b) \(Disc [0-9AB]\)(*)/}
    local suff="${match}"

    # All CD based system games should have their own subdirectories, for
    # detecting if CD change warrants a core reset (multi-CD games), and a
    # least for PSX core to automatically create a matching save file (mcd)
    #
    # Because file naming in the repositories isn't quite uniform, it's a bit
    # of a pain in the ass. Some multi-CD titles have multiple versions and
    # each disk additionally has a unique name.
    #
    # For deducing correct directory name for multi-CD games, filename is cut
    # into three parts:
    #
    #   `Example Multi-CD Game (Disc 1) (Ugly hack) (Proto)`
    #    +-------------------+ +------+ +-----------------+
    #            base            disc         suffix

    typeset -A discset=() # discset[base]="disc:suffix\x00disc:suffix\x00"
    for ntag in $ntags; do
        local nbase=${ntag//(#b)( \(Disc [0-9AB]\))(*)/}
        [[ ! $nbase = $base ]] && continue # This should never happen
        [[ -z ${match[2]} ]] && match[2]="0xDEADBEEF" # Placeholder for no suffix
        discset[${base}]+=${:-${match[1]}":"${match[2]}$'\x00'}
    done

    # If there's only one file suffix, use it
    local -a nsuff=(${(u)${(0)discset[$base]}##*:})
    (( $#nsuff == 1 )) && { print "${base}${suff}" ; return }

    # If there's multiple suffixes but only one set of discs, just use base name
    local -a discs=(${${(0)discset[$base]}%%:*})
    (( $#discs == ${#${(@u)discs}} )) && { print "${base}" ; return }

    # If the number of disc sets matches the number of different suffixes,
    # *assume* there's a unique suffix per set
    local dsets=$(( ${#discs} / ${#${(@u)discs}} ))
    (( $dsets == $#nsuff )) && { print "${base}${suff}" ; return }

    # This is as far as I'm willing to go with programmatical heuristics
    print ; return 1
}

game_menu () {
    local -a all_tags selected_tags menu_tags menu_items subdirs submenu
    local -i itemwidth retval i
    local filter tmpdata st rominfo sub match mbegin mend n

    # Full list of all games in current core XML
    tmpdata=$($XMLLINT $CORE_FILES_XML --xpath "files/file[sha1]/@name")
    all_tags=(${${${${${(@f)tmpdata}#*\"}%\"*}:#^*.(7z|zip|chd)}//\&amp\;/&})
    unset tmpdata

    # This *tarded sorting method crashes the whole MiSTer with bigger
    # repositories - reserves *far* too much memory, sigh. Looks cool tho.
    #all_tags=(${${(o)all_tags:t}/(#b)(*)/${(M)all_tags:#*${match}}})

    if [[ -n ${(M)all_tags:#*/*} ]]; then
    # Sorting with an associative array instead.. lame lol
    local -A tt
    for n in $all_tags ; tt[${n:t}]=${n:h}
    all_tags=()
    for n in ${(ok)tt} ; all_tags+=(${tt[$n]}/$n)
    unset tt
    fi
    # First check if repository contains subdirectories and if
    # user wants to only look at a specific one or all of them
    subdirs=(${(u)all_tags//(#b)(*\/)*/$match[1]})
    if (( $#subdirs != $#all_tags )) && (( $#subdirs > 1 )); then
        submenu=("ALL" "[[ All of them ]]")
        for sub in $subdirs; submenu+=($sub $sub)
        $DIALOG --clear --title $TITLE --no-tags --menu \
            "This repository contains subdirectories, please select which one to browse." \
            0 0 0 $submenu 2>$DIALOG_TEMPFILE
        (( $? != $DIALOG_OK )) && return
        sub=$(<$DIALOG_TEMPFILE)
        if [[ ! "$sub" = "ALL" ]] ; then
            all_tags=(${(M)all_tags:#${sub}*})
            sub="subdirectory: ${sub%\/}, "
        else unset sub
        fi
    fi

    # Main loop
    while true; do
        if [[ -z $selected_tags ]]; then
            # Optional filter string for narrowing down the game list
            if [[ -n $filter ]]; then
                menu_tags=(${(M)all_tags:#(#i)*${filter}*})
            else
                menu_tags=($all_tags)
            fi
        fi

        # Due to cdialog bug, checklist doesn't wrap correctly.
        # For display, remove any prefix subdirectories and file extension, then trim length if needed.
        # XXX: ${array[(r)${(l.${#${(O@)array//?/X}[1]}..?.)}]} <- only cut prefix if needed?
        itemwidth=$(( $MAXWIDTH - 14 ))
        menu_items=()
        for (( i=1 ; i<=${#menu_tags}; ++i )) ; do
            # Restore selected items, if any
            (( ${selected_tags[(Ie)${menu_tags[$i]}]} )) && st="On" || st="0"
            $JOY_MODE && unset st
            menu_items+=(${menu_tags[$i]} ${${${menu_tags[$i]##*/}%.(7z|zip|chd)}:0:$itemwidth} $st)
        done

        if [[ -z $menu_items ]]; then
            $DIALOG --msgbox "No games found with filter: $filter\n" 5 42
            # If user does not press ok, bail out instead of reloading default set
            [[ $? -ne $DIALOG_OK ]] && break
            unset filter ; continue
        fi

        ###############
        # Main ROM menu
        if $JOY_MODE; then
            $DIALOG --clear --title $TITLE --extra-button --extra-label "ROM info" \
                --no-tags --cancel-label "Back" --ok-label "Download" --default-item "$selected_tags"\
                --menu "Choose game to download (core: ${CORE}, ${sub}games total: ${#menu_tags})" \
                $MAXHEIGHT $MAXWIDTH $#menu_tags $menu_items 2>$DIALOG_TEMPFILE
        else
            $DIALOG --clear --title $TITLE --separate-output --extra-button --extra-label "ROM info" \
                --no-tags --cancel-label "Back" --help-button --help-tags --help-label "Filter..." \
                --ok-label "Download" --default-item "${selected_tags[1]}" \
                --checklist "Choose game(s) to download (core: ${CORE}, ${sub}games total: $#menu_tags)" \
                $MAXHEIGHT $MAXWIDTH $#menu_tags $menu_items 2>$DIALOG_TEMPFILE
        fi
        retval=$?
        # List of user selected tags
        selected_tags=(${${(f)"$(<$DIALOG_TEMPFILE)"}//&amp\;/&})

        case $retval in
            # Download selected games
            $DIALOG_OK)
                if [[ -z $selected_tags ]]; then
                    $DIALOG --title $TITLE --msgbox "No ROMs selected!" 0 0
                    continue
                fi
                download_roms $selected_tags
                # In simple mode, return navigation to last downloaded item
                $JOY_MODE || unset selected_tags filter
                continue ;;

            # Help button is for filtering the ROM list
            $DIALOG_HELP)
                $DIALOG --title "Game list filter" --clear --no-cancel \
                    --inputbox "Type search keyword (case-insensitive) or clear to reset list:" \
                    0 80 $filter 2>$DIALOG_TEMPFILE
                # ESC was pressed, or something else than Ok button
                [[ $? -ne $DIALOG_OK ]] && cleanup
                filter="$(<$DIALOG_TEMPFILE)"
                unset selected_tags
                continue ;;

            # Show some data for selected ROM(s)
            $DIALOG_EXTRA)
                if [[ -z $selected_tags ]]; then
                    $DIALOG --title $TITLE --msgbox "No ROMs selected!" 0 0
                    continue
                fi
                rominfo="$(get_rom_info $selected_tags)"
                $DIALOG --title "Information for selected ROM(s)" --clear --cr-wrap --colors \
                    --msgbox "$rominfo" $(( $MAXHEIGHT / 2 )) $MAXWIDTH 2>$DIALOG_TEMPFILE
                [[ $? -ne $DIALOG_OK ]] && cleanup
                continue ;;

            $DIALOG_CANCEL) break ;;
            *) cleanup ;;
        esac
    done
}

################################################################################################################
#
# MAIN SCREEN TURN ON
#
main () {
    local -i retval
    local jm t d

    init_static_globals

    # Work directory contains:
    # - Downloaded ROM repository XML metadata files, indicated by $DLDONE file
    # - User configurable settings in $SETTINGS_SH
    # - Cache dir for temporarily storing downloaded ROMs
    [[ -d $WRK_DIR ]] || mkdir -p $WRK_DIR
    [[ -d $CACHE_DIR ]] || mkdir $CACHE_DIR
    pushd $WRK_DIR

    # Cleanup in case of unclean exit
    trap 'cleanup' $SIG_HUP $SIG_INT $SIG_QUIT $SIG_TERM

    # Fetch user-configurable configuration settings from ${SETTINGS_SH} or create it if it
    # doesn't yet exist, then set defaults for all which weren't explicitly set by the user.
    get_config

    # Secret feature, if optional cmdline argument is the path to 0MHz DOS collection MGL
    # directory, append <setname> tags and copy configs for all of them
    [[ $* == "/media/fat/_DOS Games" ]] && { ao486_setnames_all ; return }

    # Login to archive.org if IA_USER/IA_PASS are set and use a cookie for remainder of
    # download operations.
    ia_login

    # Download ROM repository metadata XML files, if they haven't already been downloaded.
    fetch_metadata

    # Secret feature, optional cmdline argument is a directory with .CHD files
    # to sort into their own subdirectories.
    [[ -n $* ]] && { organise_chd_dir $* ; return }

    ###########
    # Main loop
    while true; do
        # Restore menu position, if any
        local default_item=${CORE:-0}

        # Set special title for simple mode
        $JOY_MODE && jm=" (Simple Mode)" || unset jm
        typeset -g TITLE="${ROMWEASEL_VERSION}${jm}"

        # Show main ROM repository menu.
        # A dynamic "QUEUE" pseudo-entry is prepended so the user can
        # reach queue_view without sacrificing a dialog button slot.
        $JOY_MODE && jm="Normal Mode" || jm="Simple Mode"
        local -a menu_entries=()
        local qcounts=($(queue_counts))
        local qtotal=$(( qcounts[1] + qcounts[2] + qcounts[3] + qcounts[4] + qcounts[5] + qcounts[6] ))
        local qlabel
        if (( qtotal > 0 )); then
            qlabel="[Queue]  ${qcounts[1]} waiting, ${qcounts[2]} running, ${qcounts[4]} done"
        else
            qlabel="[Queue]  (empty)"
        fi
        menu_entries+=("QUEUE" "$qlabel")
        menu_entries+=($SUPPORTED_CORES)
        $DIALOG --title $TITLE --cancel-label "Quit" --help-button --help-tags --help-status \
            --default-item "$default_item" --extra-button --extra-label "Info" --help-label $jm \
            --menu "Choose target system/repository:" 0 80 0 $menu_entries 2>$DIALOG_TEMPFILE
        retval=$?

        case $retval in
            # Open game list for selected ROM repository (or queue view)
            $DIALOG_OK)
                local picked=$(<$DIALOG_TEMPFILE)
                if [[ $picked == "QUEUE" ]]; then
                    queue_view
                else
                    select_core $picked
                    game_menu
                fi ;;

            # Repurposed for toggling simplified joystick mode on and off
            $DIALOG_HELP)
                local helpsel=${(@f)$(<$DIALOG_TEMPFILE)[2]}
                [[ $helpsel == "QUEUE" ]] && continue
                select_core $helpsel
                $JOY_MODE && { JOY_MODE=false ; jm='\Z6Disabled!\Zn' } || { JOY_MODE=true ; jm='\Z5Enabled!\Zn' }
                $DIALOG --title $TITLE --cr-wrap --colors --msgbox "Simplified joystick mode:\n\n$jm" \
                    8 0 2>$DIALOG_TEMPFILE
                [[ $? -ne $DIALOG_OK ]] && cleanup
                ;;

            # Show information for currently selected ROM repository
            $DIALOG_EXTRA)
                local extrasel=$(<$DIALOG_TEMPFILE)
                if [[ $extrasel == "QUEUE" ]]; then
                    queue_view
                    continue
                fi
                select_core $extrasel
                t=$($XMLLINT $CORE_META_XML --xpath "string(metadata/title)")
                d=$($XMLLINT $CORE_META_XML --xpath "string(metadata/addeddate)")
                $DIALOG --title "ROM repository info" --msgbox "\
Core:  $CORE \n\
URL:   $CORE_URL \n\
Title: $t \n\
Added: $d" 10 $MAXWIDTH
                unset t d
                ;;

            *)
                break ;;
            esac
    done

    # Clean up temporary files
    cleanup
}

## Entry point.
## Special subcommands --dispatcher and --worker are used by the queue
## feature to re-execute the script in background-process roles. They
## set up only the minimum state needed and bypass the TUI.
typeset -gr ROMWEASEL_SELF="${0:A}"
case ${1:-} in
    --dispatcher)
        init_static_globals
        # get_config also calls set_conf_opts internally
        pushd $WRK_DIR >/dev/null 2>&1 || mkdir -p $WRK_DIR && pushd $WRK_DIR >/dev/null
        get_config
        queue_dispatcher_loop
        exit 0
        ;;
    --worker)
        init_static_globals
        pushd $WRK_DIR >/dev/null 2>&1 || mkdir -p $WRK_DIR && pushd $WRK_DIR >/dev/null
        get_config
        queue_worker_run "$2"
        exit 0
        ;;
    *)
        main $*
        ;;
esac
