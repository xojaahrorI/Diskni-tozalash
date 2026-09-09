#!/bin/bash
# ============================================================
# DISK ANALYZER — Kali Linux uchun to'liq disk tahlil vositasi
# Diagrammalar bilan HTML hisobot yaratadi
# ============================================================

set -e

REPORT_DIR="$HOME/disk_report"
HTML_FILE="$REPORT_DIR/hisobot.html"
mkdir -p "$REPORT_DIR"

echo "🔍 Disk tahlili boshlanmoqda... (bir necha daqiqa vaqt olishi mumkin)"
echo ""

# ---------- Umumiy disk holati ----------
echo "📊 Umumiy disk holati aniqlanmoqda..."
DF_OUTPUT=$(df -h / | tail -1)
TOTAL_SIZE=$(echo "$DF_OUTPUT" | awk '{print $2}')
USED_SIZE=$(echo "$DF_OUTPUT" | awk '{print $3}')
AVAIL_SIZE=$(echo "$DF_OUTPUT" | awk '{print $4}')
USE_PERCENT=$(echo "$DF_OUTPUT" | awk '{print $5}' | tr -d '%')

# ---------- Uy papkasidagi eng katta papkalar ----------
echo "📁 Eng katta papkalar aniqlanmoqda (Home)..."
HOME_DIRS=$(du -h --max-depth=1 "$HOME" 2>/dev/null | sort -rh | grep -v "^$(du -sh $HOME 2>/dev/null | cut -f1)" | head -15)

# ---------- Tizim papkalari (root) ----------
echo "📁 Tizim papkalari aniqlanmoqda (/)..."
ROOT_DIRS=$(sudo du -h --max-depth=1 / 2>/dev/null | sort -rh | head -15)

# ---------- Eng katta fayllar (100MB dan katta) ----------
echo "📄 Eng katta fayllar qidirilmoqda (>100MB)..."
BIG_FILES=$(sudo find / -xdev -type f -size +100M -exec du -h {} \; 2>/dev/null | sort -rh | head -20)

# ---------- Odatiy "og'irlik" manbalari ----------
echo "🗑️  Keshlar va vaqtinchalik fayllar tekshirilmoqda..."

APT_CACHE=$(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)
JOURNAL_SIZE=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+[KMGT]' | head -1)
TMP_SIZE=$(du -sh /tmp 2>/dev/null | cut -f1)
USER_CACHE=$(du -sh "$HOME/.cache" 2>/dev/null | cut -f1)
VAR_LOG=$(du -sh /var/log 2>/dev/null | cut -f1)
TRASH_SIZE=$(du -sh "$HOME/.local/share/Trash" 2>/dev/null | cut -f1)
DOWNLOADS_SIZE=$(du -sh "$HOME/Downloads" 2>/dev/null | cut -f1)
DOCKER_SIZE="Mavjud emas"
if command -v docker &> /dev/null; then
    DOCKER_SIZE=$(sudo du -sh /var/lib/docker 2>/dev/null | cut -f1)
fi
SNAP_SIZE="Mavjud emas"
if [ -d /var/lib/snapd ]; then
    SNAP_SIZE=$(du -sh /var/lib/snapd 2>/dev/null | cut -f1)
fi

echo "🎨 HTML hisobot yaratilmoqda..."

# ---------- HTML uchun bar chart qatorlarini yasovchi funksiya ----------
build_bars() {
    local data="$1"
    local max_val=0
    local lines=()
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        size=$(echo "$line" | awk '{print $1}')
        name=$(echo "$line" | cut -f2-)
        num=$(echo "$size" | sed 's/[A-Za-z]*$//')
        unit=$(echo "$size" | grep -oP '[A-Za-z]+$')
        case "$unit" in
            T|TB) mb=$(awk "BEGIN{print $num*1024*1024}") ;;
            G|GB) mb=$(awk "BEGIN{print $num*1024}") ;;
            M|MB) mb=$(awk "BEGIN{print $num}") ;;
            K|KB) mb=$(awk "BEGIN{print $num/1024}") ;;
            *) mb=0 ;;
        esac
        lines+=("$mb|$size|$name")
        if (( $(awk "BEGIN{print ($mb > $max_val)}") )); then
            max_val=$mb
        fi
    done <<< "$data"

    for entry in "${lines[@]}"; do
        mb=$(echo "$entry" | cut -d'|' -f1)
        size=$(echo "$entry" | cut -d'|' -f2)
        name=$(echo "$entry" | cut -d'|' -f3)
        if (( $(awk "BEGIN{print ($max_val > 0)}") )); then
            pct=$(awk "BEGIN{printf \"%.1f\", ($mb/$max_val)*100}")
        else
            pct=0
        fi
        name_esc=$(echo "$name" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        cat <<HTMLROW
        <div class="bar-row">
          <div class="bar-label" title="$name_esc">$name_esc</div>
          <div class="bar-track"><div class="bar-fill" style="width:${pct}%"></div></div>
          <div class="bar-value">$size</div>
        </div>
HTMLROW
    done
}

HOME_BARS=$(build_bars "$HOME_DIRS")
ROOT_BARS=$(build_bars "$ROOT_DIRS")
FILES_BARS=$(build_bars "$BIG_FILES")

# ---------- HTML faylni yozish ----------
cat > "$HTML_FILE" <<HTMLEOF
<!DOCTYPE html>
<html lang="uz">
<head>
<meta charset="UTF-8">
<title>Disk Tahlil Hisoboti</title>
<style>
  * { box-sizing: border-box; }
  body {
    font-family: -apple-system, 'Segoe UI', Roboto, sans-serif;
    background: #0f1117;
    color: #e6e6e6;
    margin: 0;
    padding: 30px;
  }
  h1 { color: #ff6b35; margin-bottom: 5px; }
  .subtitle { color: #888; margin-bottom: 30px; }
  .summary-cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
    gap: 15px;
    margin-bottom: 40px;
  }
  .card {
    background: #1a1d27;
    border-radius: 12px;
    padding: 20px;
    border: 1px solid #2a2d3a;
  }
  .card .label { color: #888; font-size: 13px; text-transform: uppercase; }
  .card .value { font-size: 28px; font-weight: bold; margin-top: 5px; }
  .card.danger .value { color: #ff4757; }
  .card.warn .value { color: #ffa502; }
  .card.ok .value { color: #2ed573; }
  .card.neutral .value { color: #70a1ff; }

  .donut-wrap { display: flex; align-items: center; gap: 40px; margin-bottom: 40px; flex-wrap: wrap; }
  .donut { width: 220px; height: 220px; border-radius: 50%;
    background: conic-gradient(#ff4757 0% ${USE_PERCENT}%, #2ed573 ${USE_PERCENT}% 100%);
    display: flex; align-items: center; justify-content: center;
    position: relative;
  }
  .donut::after {
    content: "";
    width: 150px; height: 150px; border-radius: 50%;
    background: #0f1117;
    position: absolute;
  }
  .donut-text { position: relative; z-index: 2; text-align: center; }
  .donut-text .pct { font-size: 32px; font-weight: bold; }
  .donut-text .lbl { font-size: 13px; color: #888; }
  .legend { display: flex; flex-direction: column; gap: 10px; }
  .legend-item { display: flex; align-items: center; gap: 10px; font-size: 15px; }
  .dot { width: 14px; height: 14px; border-radius: 3px; }

  h2 { color: #70a1ff; border-bottom: 1px solid #2a2d3a; padding-bottom: 8px; margin-top: 45px; }
  .bar-row { display: flex; align-items: center; gap: 12px; margin: 6px 0; font-size: 14px; }
  .bar-label { width: 320px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: #ccc; }
  .bar-track { flex: 1; background: #1a1d27; border-radius: 6px; height: 20px; overflow: hidden; }
  .bar-fill { height: 100%; background: linear-gradient(90deg, #ff6b35, #ff4757); border-radius: 6px; }
  .bar-value { width: 70px; text-align: right; color: #70a1ff; font-weight: bold; }

  .hogs-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 12px; }
  .hog-item { background: #1a1d27; padding: 14px 18px; border-radius: 10px; border-left: 4px solid #ffa502; }
  .hog-item .name { color: #888; font-size: 13px; }
  .hog-item .size { font-size: 20px; font-weight: bold; margin-top: 3px; }
  .tip { background: #1a1d27; border-left: 4px solid #2ed573; padding: 14px 18px; border-radius: 8px; margin-top: 15px; font-size: 14px; color: #ccc; }
  footer { margin-top: 50px; color: #555; font-size: 12px; text-align: center; }
</style>
</head>
<body>

<h1>💾 Disk Tahlil Hisoboti</h1>
<div class="subtitle">Yaratilgan sana: $(date '+%Y-%m-%d %H:%M') | Host: $(hostname)</div>

<div class="donut-wrap">
  <div class="donut">
    <div class="donut-text">
      <div class="pct">${USE_PERCENT}%</div>
      <div class="lbl">band</div>
    </div>
  </div>
  <div class="legend">
    <div class="legend-item"><div class="dot" style="background:#ff4757"></div> Band: $USED_SIZE</div>
    <div class="legend-item"><div class="dot" style="background:#2ed573"></div> Bo'sh: $AVAIL_SIZE</div>
    <div class="legend-item"><div class="dot" style="background:#70a1ff"></div> Jami: $TOTAL_SIZE</div>
  </div>
</div>

<div class="summary-cards">
  <div class="card neutral"><div class="label">Jami hajm</div><div class="value">$TOTAL_SIZE</div></div>
  <div class="card danger"><div class="label">Band</div><div class="value">$USED_SIZE</div></div>
  <div class="card ok"><div class="label">Bo'sh</div><div class="value">$AVAIL_SIZE</div></div>
  <div class="card warn"><div class="label">To'lganlik</div><div class="value">${USE_PERCENT}%</div></div>
</div>

<h2>📁 Eng katta papkalar — Home ($HOME)</h2>
$HOME_BARS

<h2>📁 Eng katta papkalar — Tizim (/)</h2>
$ROOT_BARS

<h2>📄 Eng katta fayllar (100MB dan katta)</h2>
$FILES_BARS

<h2>🗑️ Keshlar va vaqtinchalik fayllar ("og'irlik" manbalari)</h2>
<div class="hogs-grid">
  <div class="hog-item"><div class="name">APT kesh (/var/cache/apt/archives)</div><div class="size">${APT_CACHE:-0}</div></div>
  <div class="hog-item"><div class="name">Journal loglar (systemd)</div><div class="size">${JOURNAL_SIZE:-0}</div></div>
  <div class="hog-item"><div class="name">/tmp papkasi</div><div class="size">${TMP_SIZE:-0}</div></div>
  <div class="hog-item"><div class="name">Foydalanuvchi keshi (~/.cache)</div><div class="size">${USER_CACHE:-0}</div></div>
  <div class="hog-item"><div class="name">Tizim loglari (/var/log)</div><div class="size">${VAR_LOG:-0}</div></div>
  <div class="hog-item"><div class="name">Chiqindilar savati</div><div class="size">${TRASH_SIZE:-0}</div></div>
  <div class="hog-item"><div class="name">Downloads papkasi</div><div class="size">${DOWNLOADS_SIZE:-0}</div></div>
  <div class="hog-item"><div class="name">Docker (agar mavjud)</div><div class="size">${DOCKER_SIZE:-0}</div></div>
  <div class="hog-item"><div class="name">Snap (agar mavjud)</div><div class="size">${SNAP_SIZE:-0}</div></div>
</div>

<div class="tip">
💡 <b>Tozalash bo'yicha maslahat:</b> APT kesh va journal loglarni xavfsiz tozalash mumkin:<br>
<code>sudo apt clean</code> — apt keshini tozalaydi<br>
<code>sudo journalctl --vacuum-size=50M</code> — loglarni 50MB gacha qisqartiradi<br>
<code>rm -rf ~/.cache/*</code> — foydalanuvchi keshini tozalaydi (dasturlar qayta keshlaydi, xavfsiz)
</div>

<footer>disk_analyzer.sh tomonidan avtomatik yaratildi</footer>
</body>
</html>
HTMLEOF

echo ""
echo "✅ Tahlil yakunlandi!"
echo "📄 Hisobot manzili: $HTML_FILE"
echo ""
echo "Hisobotni ochish uchun:"
echo "   xdg-open \"$HTML_FILE\""
echo "yoki Fayl menejeridan qo'lda oching."
echo ""

# Avtomatik ochishga urinish
xdg-open "$HTML_FILE" 2>/dev/null &

exit 0
