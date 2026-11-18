#!/bin/bash
# ---------------------------------------------------------------------------
# Hugo-oldal feltöltése a szerverre rsync-kel (macOS Terminal)
#
#   1. lefordítja az oldalt:  hugo --gc --minify --cleanDestinationDir
#   2. ellenőrzi, hogy a public/ mappa ép (nem üres, van index.html)
#   3. próbafuttatás: megmutatja, mi kerülne fel és mi törlődne a szerverről
#   4. megerősítés után feltölti a public/ tartalmát, és törli a szerverről
#      azt, ami a public/-ban már nincs meg
#
# Használat:
#   ./deploy.sh [projekt-mappa] [kapcsolók]
#
#   projekt-mappa   a Hugo-projekt mappája (alapértelmezés: az aktuális mappa)
#   -n, --dry-run   csak próbafuttatás, semmit nem tölt fel és nem töröl
#   -y, --yes       nem kérdez rá a feltöltésre (pl. automatizáláshoz)
#   --no-build      nem fordít, a meglévő public/ mappát tölti fel
#   -h, --help      ez a súgó
#
# Beállítás: a projekt mappájában egy deploy.conf fájl, például:
#
#   REMOTE="felhasznalo@szerver.hu:/home/felhasznalo/public_html/"
#   SSH_PORT=22                       # ha a tárhely más portot használ
#   PROTECT=(".well-known/" ".htaccess" ".user.ini" "cgi-bin/")
#
#   A PROTECT listában lévő fájlokat/mappákat a szerveren soha nem törli
#   (pl. a Let's Encrypt tanúsítvány .well-known mappája, a tárhely .htaccess-e).
#
# Előfeltétel: SSH-hozzáférés a tárhelyhez (jelszóval vagy SSH-kulccsal).
# ---------------------------------------------------------------------------
set -euo pipefail

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
die()   { red "HIBA: $*" >&2; exit 1; }

usage() { sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# --- kapcsolók --------------------------------------------------------------
PROJECT="."
DRY_ONLY=0; ASSUME_YES=0; BUILD=1
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_ONLY=1 ;;
    -y|--yes)     ASSUME_YES=1 ;;
    --no-build)   BUILD=0 ;;
    -h|--help)    usage ;;
    -*)           die "ismeretlen kapcsoló: $arg (súgó: $0 --help)" ;;
    *)            PROJECT="$arg" ;;
  esac
done

cd "$PROJECT" 2>/dev/null || die "nem létező mappa: $PROJECT"
PROJECT="$(pwd)"
[ -d content ] && { [ -d config ] || ls hugo.toml config.toml >/dev/null 2>&1; } \
  || die "ez nem Hugo-projekt mappa: $PROJECT"

# --- beállítások ------------------------------------------------------------
[ -f deploy.conf ] || die "hiányzik a $PROJECT/deploy.conf (lásd: $0 --help)"
REMOTE=""; SSH_PORT=22
PROTECT=(".well-known/" ".htaccess" ".user.ini" "cgi-bin/")
# shellcheck disable=SC1091
source ./deploy.conf

[ -n "$REMOTE" ] || die "a deploy.conf-ban nincs megadva a REMOTE"
REMOTE_PATH="${REMOTE#*:}"
case "$REMOTE_PATH" in
  ""|"/"|"~"|"~/"|"."|"./")
    die "veszélyes célmappa: '$REMOTE_PATH' – adj meg egy konkrét webmappát (pl. .../public_html/)" ;;
esac
# a záró / fontos: a public/ TARTALMA kerüljön a célmappába, ne egy public almappa
[[ "$REMOTE" == */ ]] || REMOTE="$REMOTE/"

# --- rsync kiválasztása -----------------------------------------------------
# a Homebrew rsync (brew install rsync) többet tud; ha nincs, a macOS beépített
# openrsync-je is elég
RSYNC=/usr/bin/rsync
[ -x /opt/homebrew/bin/rsync ] && RSYNC=/opt/homebrew/bin/rsync
[ -x /usr/local/bin/rsync ] && RSYNC=/usr/local/bin/rsync

# --checksum: a Hugo minden fordításkor újraírja a fájlokat (új dátummal), ezért
# tartalom alapján hasonlítunk – így csak a ténylegesen változott fájlok mennek fel
RSYNC_OPTS=(-rltz --checksum --delete --exclude ".DS_Store")
for p in "${PROTECT[@]}"; do RSYNC_OPTS+=(--exclude "$p"); done
# távoli célnál ssh-n keresztül, a megadott porton
if [[ "$REMOTE" == *:* ]]; then
  RSYNC_OPTS+=(-e "ssh -p $SSH_PORT")
fi

# --- 1. fordítás ------------------------------------------------------------
if [ "$BUILD" -eq 1 ]; then
  command -v hugo >/dev/null || die "a hugo nincs telepítve"
  bold "1/4  Fordítás: hugo --gc --minify --cleanDestinationDir"
  hugo --gc --minify --cleanDestinationDir || die "a fordítás nem sikerült, nem töltök fel semmit"
else
  bold "1/4  Fordítás kihagyva (--no-build)"
fi

# --- 2. a public/ ellenőrzése -----------------------------------------------
bold "2/4  A public/ mappa ellenőrzése"
[ -f public/index.html ] || die "nincs public/index.html – üres vagy hibás fordítás, nem töltök fel"
NFILES=$(find public -type f ! -name .DS_Store | wc -l | tr -d ' ')
[ "$NFILES" -ge 10 ] || die "a public/ mappában csak $NFILES fájl van – ez gyanús, nem töltök fel"
grep -q "example.org" public/index.html && die "a public/index.html example.org-ra hivatkozik – rossz baseURL?"
echo "     $NFILES fájl, $(du -sh public | cut -f1)"

# --- 3. próbafuttatás -------------------------------------------------------
bold "3/4  Próbafuttatás → $REMOTE"
DRY_OUT=$("$RSYNC" "${RSYNC_OPTS[@]}" -n -v public/ "$REMOTE" 2>&1) || { echo "$DRY_OUT"; die "az rsync próbafuttatás hibát adott (SSH-elérés, útvonal?)"; }
DELETES=$(printf '%s\n' "$DRY_OUT" | grep -c '^deleting ' || true)
UPLOADS=$(printf '%s\n' "$DRY_OUT" | grep -vE '^(deleting |sending |sent |total |building |created |Transfer|$)|/$' | grep -c . || true)
echo "     feltöltendő/frissítendő fájl: $UPLOADS"
echo "     a szerverről törlendő:        $DELETES"
if [ "$DELETES" -gt 0 ]; then
  echo "     törlendők (első 20):"
  printf '%s\n' "$DRY_OUT" | grep '^deleting ' | head -20 | sed 's/^/       /'
fi
# biztonsági fék: ha a szerveren lévő fájlok nagyobb részét törölné, álljon meg
if [ "$DELETES" -gt 0 ] && [ "$DELETES" -gt "$NFILES" ]; then
  red "FIGYELEM: több fájlt törölne ($DELETES), mint amennyi feltöltésre kerül ($NFILES)."
  red "Lehet, hogy rossz a REMOTE útvonal. Ellenőrizd a deploy.conf-ot!"
  [ "$ASSUME_YES" -eq 1 ] && die "--yes mellett ilyenkor nem folytatom"
fi

if [ "$DRY_ONLY" -eq 1 ]; then
  green "Próbafuttatás kész, semmi nem változott a szerveren."
  exit 0
fi

# --- 4. feltöltés -----------------------------------------------------------
if [ "$ASSUME_YES" -ne 1 ]; then
  read -r -p "Feltöltsem és töröljem a felesleget? [i/N] " ans
  [[ "$ans" =~ ^[iIyY]$ ]] || { echo "Megszakítva, semmi nem változott."; exit 0; }
fi
bold "4/4  Feltöltés → $REMOTE"
"$RSYNC" "${RSYNC_OPTS[@]}" public/ "$REMOTE" || die "a feltöltés hibával állt le"
green "Kész: $(date '+%Y-%m-%d %H:%M') – $UPLOADS fájl feltöltve, $DELETES törölve."
