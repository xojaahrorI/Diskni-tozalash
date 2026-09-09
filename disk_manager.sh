#!/bin/bash
# ============================================================
# DISK MANAGER v2 — Xavfsiz, 3 bosqichli tizim
# 1-bosqich: KORISH (hech narsa ozgarmaydi)
# 2-bosqich: ZIP QILISH (asl fayl tegilmaydi, faqat nusxa olinadi)
# 3-bosqich: OCHIRISH (faqat zip mavjud bolganlarga, alohida tasdiq bilan)
# ============================================================

BACKUP_DIR="$HOME/ochirilganlar_backup"
MANIFEST="$BACKUP_DIR/manifest.txt"
mkdir -p "$BACKUP_DIR"
touch "$MANIFEST"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

pause() { read -rp "Davom etish uchun Enter bosing..."; }

# ------------------------------------------------------------
# Diskning umumiy holati
# ------------------------------------------------------------
umumiy_holat() {
    echo -e "\n${BLUE}=== DISK HOLATI ===${NC}"
    df -h /
    echo ""
}

# ------------------------------------------------------------
# BOSQICH 1: Faqat korsatish, hech narsa ozgarmaydi
# ------------------------------------------------------------
korish_katta_narsalar() {
    echo -e "\n${BLUE}=== HOMEDAGI ENG KATTA 20 TA PAPKA/FAYL (faqat korish) ===${NC}\n"
    du -h --max-depth=1 "$HOME" 2>/dev/null | sort -rh | grep -v "^$(du -sh "$HOME" 2>/dev/null | cut -f1)" | head -20 | nl -w2 -s") "
    echo ""
    echo -e "${YELLOW}Hech narsa ozgartirilmadi, bu faqat royxat.${NC}"
}

korish_nusxalar() {
    echo -e "\n${BLUE}=== NUSXA (COPY) NOMLI PAPKA/FAYLLAR (faqat korish) ===${NC}\n"
    mapfile -t topilganlar < <(find "$HOME" -maxdepth 3 \( -iname "*copy*" -o -iname "*nusxa*" -o -iname "* (1)*" \) 2>/dev/null | grep -v "$BACKUP_DIR")

    if [ ${#topilganlar[@]} -eq 0 ]; then
        echo -e "${GREEN}Hech qanday nusxa topilmadi.${NC}"
        return
    fi

    i=1
    for item in "${topilganlar[@]}"; do
        size=$(du -sh "$item" 2>/dev/null | cut -f1)
        echo "$i) [$size]  $item"
        i=$((i+1))
    done
    echo ""
    echo -e "${YELLOW}Hech narsa ozgartirilmadi, bu faqat royxat.${NC}"
}

korish_katta_fayllar() {
    echo -e "\n${BLUE}=== 100MB DAN KATTA FAYLLAR (faqat korish, biroz vaqt oladi) ===${NC}\n"
    sudo find "$HOME" -type f -size +100M -exec du -h {} \; 2>/dev/null | sort -rh | head -20 | nl -w2 -s") "
    echo ""
    echo -e "${YELLOW}Hech narsa ozgartirilmadi, bu faqat royxat.${NC}"
}

# ------------------------------------------------------------
# BOSQICH 2: Faqat ZIP qilish (asl fayl saqlanib qoladi)
# ------------------------------------------------------------
zip_qilish() {
    echo -e "\n${BLUE}=== ZIP QILISH (BACKUP OLISH) ===${NC}"
    echo "Bu bosqichda hech narsa OCHIRILMAYDI. Faqat nusxa (zip) olinadi."
    echo "Asl fayl/papka joyida qoladi."
    echo ""
    read -rp "Zip qilinadigan papka yoki fayl manzilini kiriting (masalan: /home/kali/Downloads/eski_fayl): " target

    if [ ! -e "$target" ]; then
        echo -e "${RED}Bunday fayl yoki papka topilmadi: $target${NC}"
        return
    fi

    size_before=$(du -sh "$target" 2>/dev/null | cut -f1)
    echo -e "${YELLOW}Tanlandi: $target (hajmi: $size_before)${NC}"
    read -rp "Zip qilinsinmi? (h=ha / boshqa=yoq): " tasdiq
    if [ "$tasdiq" != "h" ]; then
        echo "Bekor qilindi."
        return
    fi

    local base_name
    base_name=$(basename "$target")
    local zip_path="$BACKUP_DIR/${base_name// /_}_$(date +%Y%m%d_%H%M%S).zip"

    echo -e "${BLUE}Zip qilinmoqda, kuting...${NC}"
    if ! zip -rq "$zip_path" "$target"; then
        echo -e "${RED}Zip qilishda xatolik yuz berdi.${NC}"
        return
    fi

    echo -e "${BLUE}Zip fayl tekshirilmoqda...${NC}"
    if unzip -tq "$zip_path" > /dev/null 2>&1; then
        echo -e "${GREEN}TAYYOR. Zip fayl butun va togri: $zip_path${NC}"
        echo "$target|$zip_path" >> "$MANIFEST"
        echo -e "${YELLOW}Asl fayl hali joyida turibdi, hech narsa ochirilmadi.${NC}"
        echo -e "${YELLOW}Ochirish uchun asosiy menyudan 5-bolimga (OCHIRISH) kiring.${NC}"
    else
        echo -e "${RED}Zip fayl buzilgan chiqdi. Asl fayl tegilmadi.${NC}"
        rm -f "$zip_path"
    fi
}

# ------------------------------------------------------------
# BOSQICH 3: Faqat ZIP qilinganlarni ochirish, alohida tasdiq bilan
# ------------------------------------------------------------
ochirish_bolimi() {
    echo -e "\n${BLUE}=== OCHIRISH (faqat avval zip qilinganlar) ===${NC}\n"

    if [ ! -s "$MANIFEST" ]; then
        echo -e "${YELLOW}Hozircha hech narsa zip qilinmagan. Avval 4-bolimdan (ZIP QILISH) foydalaning.${NC}"
        return
    fi

    echo -e "${BOLD}Zip qilingan va ochirishga tayyor royxat:${NC}\n"
    i=1
    declare -a manifest_lines=()
    while IFS='|' read -r orig zippath; do
        if [ -e "$orig" ]; then
            zsize=$(du -sh "$zippath" 2>/dev/null | cut -f1)
            echo "$i) $orig"
            echo "     zip: $zippath ($zsize)"
            manifest_lines+=("$orig|$zippath")
            i=$((i+1))
        fi
    done < "$MANIFEST"

    if [ $i -eq 1 ]; then
        echo -e "${GREEN}Barchasi allaqachon ochirilgan yoki manifest bosh.${NC}"
        return
    fi

    echo ""
    read -rp "Qaysi raqamni OCHIRMOQCHISIZ? (raqam kiriting, bekor qilish uchun Enter): " num
    if [ -z "$num" ]; then
        echo "Bekor qilindi."
        return
    fi

    idx=$((num-1))
    entry="${manifest_lines[$idx]}"
    orig=$(echo "$entry" | cut -d'|' -f1)
    zippath=$(echo "$entry" | cut -d'|' -f2)

    echo ""
    echo -e "${YELLOW}Siz tanladingiz: $orig${NC}"
    echo -e "${YELLOW}Zip nusxasi: $zippath${NC}"
    echo ""
    echo -e "${RED}Bu amal ORQAGA QAYTMAYDI (lekin zip nusxasi saqlanib qoladi).${NC}"
    read -rp "Tasdiqlash uchun OCHIRAMAN deb yozing: " tasdiq

    if [ "$tasdiq" != "OCHIRAMAN" ]; then
        echo "Bekor qilindi (togri soz yozilmadi)."
        return
    fi

    if unzip -tq "$zippath" > /dev/null 2>&1; then
        rm -rf "$orig"
        echo -e "${GREEN}Ochirildi: $orig${NC}"
        echo -e "${GREEN}Zip nusxasi hali ham saqlangan: $zippath${NC}"
    else
        echo -e "${RED}DIQQAT: zip fayl buzilgan, ochirish BEKOR QILINDI. Asl fayl xavfsiz turibdi.${NC}"
    fi
}

# ------------------------------------------------------------
# Xavfsiz avtomatik tozalash (kesh, log, trash - hech qachon shaxsiy fayl emas)
# ------------------------------------------------------------
xavfsiz_tozalash() {
    echo -e "\n${BLUE}=== XAVFSIZ TOZALASH ===${NC}"
    echo "Bular sizning shaxsiy fayllaringiz EMAS, dastur keshlari:"
    echo "  - APT kesh"
    echo "  - Systemd journal loglar"
    echo "  - Chiqindilar savati (Trash)"
    echo "  - Foydalanuvchi keshi (~/.cache)"
    echo ""
    read -rp "Davom etilsinmi? (h=ha / boshqa=yoq): " javob
    if [ "$javob" != "h" ]; then
        echo "Bekor qilindi."
        return
    fi

    sudo apt clean
    sudo journalctl --vacuum-size=30M
    rm -rf "$HOME/.local/share/Trash/"* 2>/dev/null
    rm -rf "$HOME/.cache/"* 2>/dev/null

    echo -e "${GREEN}Tozalash yakunlandi.${NC}"
}

# ------------------------------------------------------------
# Backup arxivlarni korish/ochirish
# ------------------------------------------------------------
backup_holati() {
    echo -e "\n${BLUE}=== SAQLANGAN ZIP ARXIVLAR ===${NC}"
    if [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null | grep -v manifest.txt)" ]; then
        echo "Hozircha zip arxiv yoq."
        return
    fi
    ls -lh "$BACKUP_DIR" | grep -v manifest.txt
    total=$(du -sh "$BACKUP_DIR" | cut -f1)
    echo ""
    echo "Jami backup hajmi: $total"
}

# ------------------------------------------------------------
# ASOSIY MENYU
# ------------------------------------------------------------
while true; do
    clear
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}       DISK MANAGER v2 - Kali Linux${NC}"
    echo -e "${BLUE}================================================${NC}"
    umumiy_holat
    echo "Nima qilmoqchisiz?"
    echo -e "  ${BOLD}KORISH (xavfsiz, hech narsa ozgarmaydi):${NC}"
    echo "  1) Eng katta papka/fayllarni korish"
    echo "  2) Nusxa (copy) nomli papka/fayllarni korish"
    echo "  3) 100MB dan katta fayllarni korish"
    echo -e "  ${BOLD}ZIP VA OCHIRISH:${NC}"
    echo "  4) Tanlangan fayl/papkani ZIP qilish (asl fayl tegilmaydi)"
    echo "  5) Zip qilinganlarni OCHIRISH (alohida tasdiq talab qiladi)"
    echo -e "  ${BOLD}BOSHQA:${NC}"
    echo "  6) Xavfsiz avtomatik tozalash (kesh, log, trash)"
    echo "  7) Saqlangan zip arxivlarni korish"
    echo "  8) Tolik HTML hisobot yaratish (diagrammali)"
    echo "  0) Chiqish"
    echo ""
    read -rp "Tanlang [0-8]: " tanlov

    case "$tanlov" in
        1) korish_katta_narsalar; pause ;;
        2) korish_nusxalar; pause ;;
        3) korish_katta_fayllar; pause ;;
        4) zip_qilish; pause ;;
        5) ochirish_bolimi; pause ;;
        6) xavfsiz_tozalash; pause ;;
        7) backup_holati; pause ;;
        8)
            if [ -f "$HOME/disk_analyzer.sh" ]; then
                bash "$HOME/disk_analyzer.sh"
            else
                echo -e "${RED}disk_analyzer.sh topilmadi.${NC}"
            fi
            pause
            ;;
        0) echo "Xayr"; exit 0 ;;
        *) echo "Notogri tanlov."; pause ;;
    esac
done
