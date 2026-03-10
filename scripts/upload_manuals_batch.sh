#!/bin/bash
# Загрузка мануалов на сервер
cd "$(dirname "$0")/.."
source scripts/upload_env.sh

FILES=(
  "/Users/admin/Downloads/Citroen_2011_Citroën_C4_Citroen_C4_Aircross_2011_Owner's_Manual.pdf"
  "/Users/admin/Downloads/Chevrolet_1985_Chevrolet_Spectrum_Chevrolet_Spectrum_1985_1993_Repair.pdf"
  "/Users/admin/Downloads/Chery_2008_Chery_M11_Chery_M11_CVT_Owner's_Manual.pdf"
  "/Users/admin/Downloads/BMW_2009_BMW_1_Series_BMW_135i_Coupe_2009.pdf"
)

for f in "${FILES[@]}"; do
  if [ -f "$f" ]; then
    echo "Загрузка: $f"
    python3 scripts/upload_manual.py "$f"
    echo "---"
  else
    echo "Файл не найден: $f"
  fi
done

echo "Готово."
