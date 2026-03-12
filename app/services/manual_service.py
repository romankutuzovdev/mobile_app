from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional, List
from uuid import UUID
import io
import logging
import re
import sys

from app.repositories.manual_repository import ManualRepository
from app.repositories.qdrant_repository import QdrantRepository
from app.schemas.manual import ManualOut
from app.services.embedding_service import EmbeddingService

logger = logging.getLogger(__name__)


class ManualService:
    """Сервис для работы с мануалами"""

    CHUNK_SIZE = 800
    CHUNK_OVERLAP = 150

    @staticmethod
    def _deduplicate_model_words(model: str) -> str:
        """Убрать повторяющиеся подряд слова: CTS CTS SPORT WAGON -> CTS SPORT WAGON."""
        words = model.split()
        if len(words) < 2:
            return model
        seen = [words[0]]
        for w in words[1:]:
            if w.upper() != seen[-1].upper():
                seen.append(w)
        return " ".join(seen)

    @staticmethod
    def _parse_manual_metadata(title: str, filename: str, content_preview: Optional[str] = None) -> dict:
        """Извлечь brand, model, year из имени файла (основной источник) и title. Содержимое — только для года, т.к. в PDF часто попадают заголовки разделов."""
        year = None
        # Ищем год в filename, title, content (\b не сработает для Chevrolet_2008_HHR)
        for s in (filename, title, content_preview or ""):
            if not s:
                continue
            m = re.search(r'(19\d{2}|20\d{2})', s)
            if m:
                y = int(m.group(1))
                if 1900 <= y <= 2100:
                    year = y
                    break

        # Имя файла — главный источник (наиболее надёжный: Cadillac_2013_CTS_...)
        name = filename.split(".")[0] if "." in filename else filename
        parts = [p for p in re.split(r'[\s_\-]+', name) if p]
        brand_from_file = model_from_file = None
        if len(parts) >= 2:
            brand_from_file = parts[0]
            model_parts = []
            for p in parts[1:]:
                if year and p == str(year):
                    continue
                if brand_from_file and p.upper() == brand_from_file.upper():
                    continue
                if p.lower() in ("owners", "manual", "ownermanual", "pdf", "owner"):
                    break
                model_parts.append(p)
            model_from_file = " ".join(model_parts) if model_parts else (parts[1] if len(parts) > 1 else None)
            if model_from_file:
                model_from_file = ManualService._deduplicate_model_words(model_from_file)

        # Title — запасной вариант
        words = title.replace(",", " ").split()
        stop_words = {"owners", "manual", "guide", "handbook", "service", "repair"}
        brand_from_title = words[0] if words else None
        model_from_title_parts = []
        for w in words[1:]:
            if w.isdigit() and len(w) == 4:
                continue
            if w.lower() in stop_words:
                break
            model_from_title_parts.append(w)
        model_from_title = " ".join(model_from_title_parts) if model_from_title_parts else None

        # Приоритет: filename > title. Содержимое НЕ перезаписывает brand/model (там заголовки разделов)
        brand = brand_from_file or brand_from_title or "Unknown"
        model = model_from_file or model_from_title or "Manual"
        year = year or 2000

        # Из content берём только год (если не нашли в filename/title)
        if content_preview and len(content_preview.strip()) > 50 and year == 2000:
            ref = ManualService._extract_metadata_from_content(content_preview)
            if ref.get("year") and 1900 <= ref["year"] <= 2100:
                year = ref["year"]

        return {"brand": brand.strip()[:100], "model": (model or "Manual").strip()[:100], "year": year}

    @staticmethod
    def _extract_metadata_from_content(text: str) -> dict:
        """Извлечь brand, model, year из текста мануала (первые страницы)."""
        result = {}
        sample = text[:4000] if len(text) > 4000 else text
        # Год: Model Year 2015, Year: 2015, 2015 Model, (2015)
        year_m = re.search(r'(?:model\s+year|year|год|модельный\s+год)[:\s]*(\d{4})', sample, re.IGNORECASE)
        if year_m:
            y = int(year_m.group(1))
            if 1900 <= y <= 2100:
                result["year"] = y
        if "year" not in result:
            year_m2 = re.search(r'\b(19\d{2}|20\d{2})\b', sample)
            if year_m2:
                y = int(year_m2.group(1))
                if 1900 <= y <= 2100:
                    result["year"] = y

        # Паттерны: "Honda Accord", "BMW 3 Series", "Chevrolet HHR"
        # Часто на первой странице: "Owner's Manual for 2015 Honda Accord" или "для Honda Accord"
        for pattern in [
            r'(?:owner[\'s]?\s*manual|руководство)[\s—\-]+(?:\d{4}\s+)?([A-Za-z]+)\s+([A-Za-z0-9\s\-]+?)(?:\s+\d{4}|\.|\s*$)',
            r'(?:for|для)\s+(?:\d{4}\s+)?([A-Za-z]+)\s+([A-Za-z0-9\s\-]+?)(?:\s*\.|\s+\d{4}|$)',
            r'(?:for|для)\s+([A-Za-z]+)\s+([A-Za-z0-9\s\-]+)',
            r'^([A-Za-z]+)\s+([A-Za-z0-9\s\-]{2,50}?)(?:\s+owner|\s+manual|\s+\d{4}|\.|$)',
        ]:
            m = re.search(pattern, sample, re.IGNORECASE | re.MULTILINE)
            if m:
                b, mod = m.group(1).strip(), m.group(2).strip()
                section_words = {"performance", "instruments", "controls", "the", "for", "and", "this", "safety"}
                if len(b) >= 2 and len(mod) >= 1 and b.lower() not in section_words and mod.lower() not in section_words:
                    result["brand"] = b
                    result["model"] = mod[:80]
                    break

        return result

    @staticmethod
    def _debug(msg: str) -> None:
        """Вывод отладочной информации в stderr (не буферизуется при docker exec)."""
        sys.stderr.write(f"[DEBUG] {msg}\n")
        sys.stderr.flush()

    @staticmethod
    async def upload_manual(
        db: AsyncSession,
        file_content: bytes,
        filename: str,
        title: str,
        car_id: Optional[int] = None,
        user_id: Optional[int] = None,
        use_ocr_for_pdf: bool = False
    ) -> ManualOut:
        """Загрузка и обработка мануала. Без car_id — создаёт запись в каталоге (car) из title/filename/содержимого и привязывает мануал."""
        ManualService._debug(f"=== НАЧАЛО ЗАГРУЗКИ: {filename} ({len(file_content)/1024:.1f} KB) ===")
        ManualService._debug("Шаг 1/6: Парсинг файла (извлечение текста)...")
        # Сначала парсим файл — нужен текст и для чанков, и для улучшенного определения марки/модели/года
        if use_ocr_for_pdf and filename.lower().endswith(".pdf"):
            sys.stderr.write("📄 Режим: принудительный OCR по всему PDF (все страницы)...\n")
            sys.stderr.flush()
            text_content = await ManualService._parse_pdf_with_ocr(file_content)
        else:
            text_content = await ManualService._parse_file(file_content, filename)

        if not text_content:
            raise ValueError("Не удалось извлечь текст из файла")
        ManualService._debug(f"   → Извлечено {len(text_content)} символов текста")

        ManualService._debug("Шаг 2/6: Нормализация текста (колонтитулы, пробелы)...")
        # Нормализация: удаление колонтитулов, исправление слипшихся слов (PDF часто без пробелов)
        text_content = ManualService._remove_headers_footers(text_content)
        text_content = ManualService._fix_run_together_words(text_content)
        logger.info("Текст мануала нормализован (футеры, пробелы)")

        ManualService._debug("Шаг 3/6: Извлечение метаданных (марка, модель, год)...")
        content_preview = text_content[:4000] if len(text_content) > 4000 else text_content
        meta = ManualService._parse_manual_metadata(title, filename, content_preview)
        ManualService._debug(f"   → brand={meta['brand']}, model={meta['model']}, year={meta['year']}")
        # Название в БД всегда «Марка Модель Год» из имени файла
        manual_title = f"{meta['brand']} {meta['model']} {meta['year']}"

        ManualService._debug("Шаг 4/6: Создание записи мануала в PostgreSQL...")
        # Мануал в глобальный каталог — car_id не нужен
        manual = await ManualRepository.create_manual(
            db=db,
            title=manual_title,
            source_file=filename,
            brand=meta["brand"],
            model=meta["model"],
            year=meta["year"],
            car_id=car_id
        )
        ManualService._debug(f"   → manual_id={manual.id}")
        logger.info(f"Мануал добавлен в глобальный каталог: {meta['brand']} {meta['model']} ({meta['year']})")

        ManualService._debug("Шаг 5/6: Разбиение текста на чанки (CHUNK_SIZE=800, OVERLAP=150)...")
        chunks = ManualService._split_text_into_chunks(text_content)
        
        # Фильтруем пустые и мусорные чанки
        valid_chunks = []
        for chunk in chunks:
            if ManualService._is_valid_chunk(chunk):
                valid_chunks.append(chunk)
            else:
                logger.warning(f"Пропущен мусорный чанк: {chunk[:100]}...")
        
        total_valid = len(valid_chunks)
        ManualService._debug(f"   → Всего чанков: {len(chunks)}, валидных (после фильтрации): {total_valid}")
        logger.info(f"Из {len(chunks)} чанков валидных: {total_valid}")
        sys.stderr.write(f"✅ Валидных чанков: {total_valid}. Начинаю загрузку в векторную БД (это может занять несколько минут)...\n")
        sys.stderr.flush()

        ManualService._debug("Шаг 6/6: Embedding каждого чанка (OpenAI) → Qdrant → PostgreSQL...")
        
        if not valid_chunks:
            # Пробуем более агрессивную очистку - удаляем все URL-ы и оставляем только текст
            logger.warning("⚠️  Не найдено валидных чанков, пробую агрессивную очистку...")
            import re
            # Удаляем все URL-ы полностью
            text_without_urls = re.sub(r'https?://[^\s]+', '', text_content, flags=re.IGNORECASE)
            text_without_urls = re.sub(r'www\.[^\s]+', '', text_without_urls, flags=re.IGNORECASE)
            # Удаляем повторяющиеся строки
            lines = text_without_urls.split('\n')
            unique_lines = []
            seen = set()
            for line in lines:
                line_clean = line.strip()
                if line_clean and line_clean not in seen and len(line_clean) > 5:
                    unique_lines.append(line_clean)
                    seen.add(line_clean)
            
            text_cleaned = '\n'.join(unique_lines)
            
            if len(text_cleaned.strip()) > 100:
                logger.info(f"✅ После агрессивной очистки осталось {len(text_cleaned)} символов")
                chunks = ManualService._split_text_into_chunks(text_cleaned)
                valid_chunks = [chunk for chunk in chunks if ManualService._is_valid_chunk(chunk)]
                logger.info(f"   Валидных чанков после очистки: {len(valid_chunks)}")
        
        if not valid_chunks:
            raise ValueError(
                "Не удалось извлечь валидный текст из файла. "
                "PDF содержит только водяные знаки или изображения. "
                "Попробуйте использовать PDF с текстовым содержимым или добавьте поддержку OCR."
            )

        # Инициализируем сервисы
        embedding_service = EmbeddingService()
        qdrant_repo = QdrantRepository()

        # Обрабатываем каждый чанк (каждый — запрос к OpenAI + сохранение)
        total = len(valid_chunks)
        for i, chunk in enumerate(valid_chunks):
            try:
                embedding = await embedding_service.get_embedding(chunk)
                embedding_id = await qdrant_repo.add_chunk(
                    embedding=embedding,
                    manual_id=manual.id,
                    brand=manual.brand,
                    model=manual.model,
                    year=manual.year,
                    page=None,
                    title=manual_title,
                    content=chunk
                )
                await ManualRepository.create_chunk(
                    db=db,
                    manual_id=manual.id,
                    content=chunk,
                    embedding_id=embedding_id,
                    page=None
                )
                logger.info(f"Обработан чанк {i+1}/{total} для мануала {manual.id}")
                # Прогресс в консоль каждые 10 чанков или на последнем (с отладкой)
                if (i + 1) % 10 == 0 or (i + 1) == total:
                    sys.stderr.write(f"   Чанк {i+1}/{total} обработан...\n")
                    sys.stderr.flush()
                if (i + 1) <= 3 or (i + 1) % 20 == 0 or (i + 1) == total:
                    ManualService._debug(f"   [{i+1}/{total}] embedding_id={embedding_id}, превью: {chunk[:60].replace(chr(10), ' ')}...")
            except Exception as e:
                logger.error(f"Ошибка при обработке чанка {i+1}: {e}")
                continue

        ManualService._debug(f"=== ЗАВЕРШЕНО: manual_id={manual.id}, загружено {total} чанков в Qdrant и PostgreSQL ===")
        sys.stderr.write(f"✅ Готово: загружено {total} чанков.\n")
        sys.stderr.flush()
        return ManualOut.model_validate(manual)

    @staticmethod
    async def _parse_file(file_content: bytes, filename: str) -> str:
        """Парсинг файла в текст"""
        file_ext = filename.lower().split('.')[-1]

        if file_ext == 'pdf':
            return await ManualService._parse_pdf(file_content)
        elif file_ext in ['docx', 'doc']:
            return await ManualService._parse_docx(file_content)
        elif file_ext == 'txt':
            return await ManualService._parse_txt(file_content)
        else:
            raise ValueError(f"Неподдерживаемый формат файла: {file_ext}")

    @staticmethod
    async def _parse_pdf(file_content: bytes) -> str:
        """Парсинг PDF файла с фильтрацией мусора"""
        import re
        
        # Пробуем сначала pdfplumber (лучше работает со сложными PDF)
        try:
            import pdfplumber
            ManualService._debug("   Парсер: pdfplumber")
            logger.info("📄 Пробую парсинг через pdfplumber...")
            
            pdf_file = io.BytesIO(file_content)
            text_parts = []
            
            with pdfplumber.open(pdf_file) as pdf:
                num_pages = len(pdf.pages)
                ManualService._debug(f"   Страниц в PDF: {num_pages}")
                logger.info(f"📄 Парсинг PDF: {num_pages} страниц")
                
                chars_total = 0
                for page_num, page in enumerate(pdf.pages):
                    page_text = page.extract_text()
                    if page_text:
                        text_parts.append(page_text)
                        chars_total += len(page_text)
                    n = page_num + 1
                    sys.stderr.write(f"\r   Парсинг: страница {n}/{num_pages} ({chars_total} символов)   ")
                    sys.stderr.flush()
                    if page_num < 3 and page_text:
                        logger.debug(f"   Страница {page_num + 1}: {page_text[:200]}...")
                sys.stderr.write("\n")  # новая строка после прогресса
                sys.stderr.flush()
            
            full_text = "\n".join(text_parts)
            ManualService._debug(f"   Сырой текст (pdfplumber): {len(full_text)} символов")
            logger.info(f"📊 Исходный текст (pdfplumber): {len(full_text)} символов")
            
        except ImportError:
            logger.warning("⚠️  pdfplumber не установлен, использую PyPDF2...")
            # Fallback на PyPDF2
            try:
                import PyPDF2
                pdf_file = io.BytesIO(file_content)
                pdf_reader = PyPDF2.PdfReader(pdf_file)
                
                num_pages = len(pdf_reader.pages)
                logger.info(f"📄 Парсинг PDF: {num_pages} страниц")
                
                text_parts = []
                chars_total = 0
                for page_num, page in enumerate(pdf_reader.pages):
                    page_text = page.extract_text()
                    if page_text:
                        text_parts.append(page_text)
                        chars_total += len(page_text)
                    n = page_num + 1
                    sys.stderr.write(f"\r   Парсинг: страница {n}/{num_pages} ({chars_total} символов)   ")
                    sys.stderr.flush()
                    if page_num < 3 and page_text:
                        logger.debug(f"   Страница {page_num + 1}: {page_text[:200]}...")
                sys.stderr.write("\n")
                sys.stderr.flush()
                
                full_text = "\n".join(text_parts)
                logger.info(f"📊 Исходный текст (PyPDF2): {len(full_text)} символов")
            except Exception as e:
                logger.error(f"Ошибка при парсинге PDF через PyPDF2: {e}")
                raise ValueError(f"Ошибка при парсинге PDF: {str(e)}")
        except Exception as e:
            logger.error(f"Ошибка при парсинге PDF через pdfplumber: {e}")
            # Пробуем PyPDF2 как fallback
            try:
                import PyPDF2
                pdf_file = io.BytesIO(file_content)
                pdf_reader = PyPDF2.PdfReader(pdf_file)
                num_pages = len(pdf_reader.pages)
                text_parts = []
                chars_total = 0
                for page_num, page in enumerate(pdf_reader.pages):
                    page_text = page.extract_text()
                    if page_text:
                        text_parts.append(page_text)
                        chars_total += len(page_text)
                    n = page_num + 1
                    sys.stderr.write(f"\r   Парсинг: страница {n}/{num_pages} ({chars_total} символов)   ")
                    sys.stderr.flush()
                sys.stderr.write("\n")
                sys.stderr.flush()
                full_text = "\n".join(text_parts)
                logger.info(f"📊 Исходный текст (PyPDF2 fallback): {len(full_text)} символов")
            except Exception as e2:
                logger.error(f"Ошибка при парсинге PDF через PyPDF2: {e2}")
                raise ValueError(f"Ошибка при парсинге PDF: {str(e)}")
        
        if not full_text or len(full_text.strip()) < 50:
            logger.warning("⚠️  Обычный парсинг не дал результатов, пробую OCR...")
            # Пробуем OCR как fallback
            try:
                ocr_text = await ManualService._parse_pdf_with_ocr(file_content)
                if ocr_text and len(ocr_text.strip()) > 100:
                    logger.info(f"✅ OCR успешно извлек {len(ocr_text)} символов текста")
                    return ocr_text
            except Exception as ocr_error:
                logger.warning(f"⚠️  OCR не удался: {ocr_error}")
            
            raise ValueError("PDF не содержит извлекаемого текста. Возможно, файл содержит только изображения.")
        
        # Фильтруем мусор: URL-ы, повторяющиеся строки
        ManualService._debug("   Очистка текста (URL, повторы)...")
        cleaned_text = ManualService._clean_text(full_text)
        ManualService._debug(f"   После очистки: {len(cleaned_text)} символов")
        logger.info(f"📊 Очищенный текст: {len(cleaned_text)} символов")
        
        if len(cleaned_text.strip()) < 100:
            logger.warning(f"⚠️  После очистки осталось очень мало текста ({len(cleaned_text)} символов)")
            logger.warning(f"   Пробую OCR как fallback...")
            # Пробуем OCR как fallback
            try:
                ocr_text = await ManualService._parse_pdf_with_ocr(file_content)
                if ocr_text and len(ocr_text.strip()) > len(cleaned_text.strip()):
                    logger.info(f"✅ OCR извлек больше текста: {len(ocr_text)} символов")
                    return ocr_text
            except Exception as ocr_error:
                logger.warning(f"⚠️  OCR не удался: {ocr_error}")
            
            # Пробуем вернуть исходный текст, но с минимальной очисткой
            # Удаляем только явные блоки URL-ов
            minimal_clean = re.sub(r'(https?://[^\s]+\s+){5,}', '', full_text)
            minimal_clean = re.sub(r'(http://www\.natahaus\.ru\s*){3,}', '', minimal_clean, flags=re.IGNORECASE)
            if len(minimal_clean.strip()) > len(cleaned_text.strip()) and len(minimal_clean.strip()) > 50:
                logger.info(f"   Используем минимально очищенный текст: {len(minimal_clean)} символов")
                return minimal_clean
        
        return cleaned_text if len(cleaned_text.strip()) > 50 else full_text
    
    @staticmethod
    def _clean_text(text: str) -> str:
        """Очистка текста от мусора (более мягкая версия)"""
        if not text:
            return ""
        
        lines = text.split('\n')
        cleaned_lines = []
        seen_lines = {}
        
        # Паттерны для фильтрации
        url_pattern = re.compile(r'^https?://|^www\.', re.IGNORECASE)
        
        for line in lines:
            original_line = line
            line = line.strip()
            
            # Пропускаем пустые строки
            if not line:
                continue
            
            # Пропускаем строки, состоящие ТОЛЬКО из URL-ов (но не строки, содержащие URL + текст)
            if url_pattern.match(line) and len(line.split()) == 1:
                continue
            
            # Пропускаем очень короткие строки (менее 2 символов), кроме чисел
            if len(line) < 2 and not (line.isdigit() or line in ['-', '.', ',']):
                continue
            
            # Пропускаем строки — только число типа score (+0,227 или 0.227), часто попадают из отладки
            if re.match(r'^[^\wа-яё]*[+-]?\d+[,.]\d+\s*$', line, re.IGNORECASE):
                continue
            
            # Пропускаем строки, которые повторяются более 3 раз подряд
            if line in seen_lines:
                seen_lines[line] += 1
                if seen_lines[line] > 3:
                    continue
            else:
                seen_lines[line] = 1
            
            # Проверяем, не состоит ли строка в основном из одного повторяющегося символа
            if len(line) > 10 and len(set(line)) < 3:
                continue
            
            # Если строка содержит URL, но также содержит другой текст - оставляем её
            # (удаляем только URL-ы из строки, но сохраняем остальной текст)
            if 'http://' in line.lower() or 'https://' in line.lower():
                # Удаляем URL-ы, но сохраняем остальной текст
                line_without_urls = re.sub(r'https?://[^\s]+', '', line, flags=re.IGNORECASE)
                line_without_urls = re.sub(r'www\.[^\s]+', '', line_without_urls, flags=re.IGNORECASE)
                line_without_urls = line_without_urls.strip()
                if len(line_without_urls) > 3:
                    cleaned_lines.append(line_without_urls)
                    continue
                else:
                    # Если после удаления URL-ов ничего не осталось - пропускаем
                    continue
            
            cleaned_lines.append(line)
        
        # Удаляем блоки повторяющихся URL-ов (более 3 подряд) из результата
        result = '\n'.join(cleaned_lines)
        url_block_pattern = re.compile(r'(https?://[^\s]+\s+){4,}', re.IGNORECASE)
        result = url_block_pattern.sub('', result)
        
        return result

    @staticmethod
    def _remove_headers_footers(text: str) -> str:
        """Удалить колонтитулы, футеры, номера страниц из текста."""
        if not text:
            return ""
        lines = text.split('\n')
        out = []
        # Паттерны типичных футеров/заголовков мануалов
        footer_patterns = [
            r'^[A-Za-z\s\-/]+Manual[\s\-]*\d{4}',  # CadillacCTS/CTS-VOwnerManual-2013
            r'^[A-Za-z\-/]+\d{4}[\s\-]*(?:crc|rev|[\d/])',  # Model2013-crc2-8/22/12
            r'^[A-Za-z]+Owner[\'s]?\s*Manual',  # Owner Manual
            r'^crc\d+[\-/]\d+[\-/]\d+',  # crc2-8/22/12
            r'^\d{1,3}\s*$',  # Номер страницы (отдельная строка)
            r'^Page\s+\d+\s+of\s+\d+$',  # Page 5 of 120
            r'^[-–—]+\s*\d+\s*[-–—]+$',  # --- 5 ---
        ]
        for line in lines:
            line_stripped = line.strip()
            if not line_stripped:
                out.append(line)
                continue
            skip = False
            for pat in footer_patterns:
                if re.match(pat, line_stripped, re.IGNORECASE):
                    skip = True
                    break
            # Строка из букв/цифр/слэшей длиной 30+ без пробелов — часто футер
            if not skip and len(line_stripped) > 35 and ' ' not in line_stripped and re.search(r'\d{4}', line_stripped):
                skip = True
            if not skip:
                out.append(line)
        return '\n'.join(out)

    @staticmethod
    def _fix_run_together_words(text: str) -> str:
        """Вставка пробелов между слипшимися словами (типично для PDF без нормальных пробелов)."""
        if not text:
            return ""
        # 0. Прямые склейки, частые в мануалах
        text = re.sub(r'and/or', r' and or ', text, flags=re.IGNORECASE)
        text = re.sub(r'lockall', r'lock all', text, flags=re.IGNORECASE)
        text = re.sub(r'lockthe', r'lock the', text, flags=re.IGNORECASE)
        text = re.sub(r'automaticseat', r'automatic seat', text, flags=re.IGNORECASE)
        # when после глагола: occurswhen, identifiedwhen
        text = re.sub(r'([a-z]{4,})when([A-Za-z])', r'\1 when \2', text, flags=re.IGNORECASE)
        # 1. Пробел между строчной и заглавной: automaticSeat -> automatic Seat
        text = re.sub(r'([a-zа-яё])([A-ZА-ЯЁ])', r'\1 \2', text)
        # 2. Пробел между заглавной и строчной (camelCase): theRKE -> the RKE
        text = re.sub(r'([A-ZА-ЯЁ]{2,})([a-zа-яё])', r'\1 \2', text)
        # 3. Разделение слипшихся слов через "and": seatandsteering -> seat and steering
        text = re.sub(r'([a-z]{2,})and([a-z]{2,})', r'\1 and \2', text, flags=re.IGNORECASE)
        # 4. Разделение через "or" (4+ букв с обеих сторон, чтобы не разбить "steering", "door")
        text = re.sub(r'([a-z]{4,})or([a-z]{4,})', r'\1 or \2', text, flags=re.IGNORECASE)
        # 5. "the" между словами: oftheDoor, leavingthevehicle -> of the Door, leaving the vehicle
        text = re.sub(r'([a-z])the([A-Z])', r'\1 the \2', text, flags=re.IGNORECASE)
        text = re.sub(r'([a-z]{3,})the([a-z]{3,})', r'\1 the \2', text, flags=re.IGNORECASE)
        # 6. "to" между словами (4+ слева; не разбивать "nto" в movement, content)
        text = re.sub(r'([a-z]{4,})(?<![n])to([a-z]{2,})', r'\1 to \2', text, flags=re.IGNORECASE)
        # 7. "of" между словами: allofthe -> all of the
        text = re.sub(r'([a-z]{2,})of([a-z]{2,})', r'\1 of \2', text, flags=re.IGNORECASE)
        # 8. "for" между словами
        text = re.sub(r'([a-z]{2,})for([a-z]{2,})', r'\1 for \2', text, flags=re.IGNORECASE)
        # 9. "in" перед заглавной: wheninMotion -> when in Motion
        text = re.sub(r'([a-z]{3,})in([A-Z][a-z])', r'\1 in \2', text, flags=re.IGNORECASE)
        # 10. "upon", "movement" — occurs upon, column movement
        text = re.sub(r'occursupon', r'occurs upon', text, flags=re.IGNORECASE)
        text = re.sub(r'columnmovement', r'column movement', text, flags=re.IGNORECASE)
        text = re.sub(r'movementoccurs', r'movement occurs', text, flags=re.IGNORECASE)
        text = re.sub(r'([a-z]{2,})orwhen', r'\1 or when', text, flags=re.IGNORECASE)
        text = re.sub(r'[,.]orwhen', r', or when', text, flags=re.IGNORECASE)
        text = re.sub(r'([a-z]{4,})is([a-z]{4,})', r'\1 is \2', text, flags=re.IGNORECASE)  # transmitterispressed
        text = re.sub(r'([a-z]{4,})upon(\s|[A-Z])', r'\1 upon \2', text, flags=re.IGNORECASE)
        # 11. Частые в мануалах: seat, door, lock, driver
        text = re.sub(r'([a-z]{3,})seat([a-z]{2,})', r'\1 seat \2', text, flags=re.IGNORECASE)
        text = re.sub(r'([a-z]{3,})door([a-z]{2,})', r'\1 door \2', text, flags=re.IGNORECASE)
        text = re.sub(r'([a-z]{3,})lock([a-z]{2,})', r'\1 lock \2', text, flags=re.IGNORECASE)
        text = re.sub(r'([a-z]{3,})driver([a-z]{2,})', r'\1 driver \2', text, flags=re.IGNORECASE)
        text = re.sub(r'([a-z]{3,})hold([a-z]{2,})', r'\1 hold \2', text, flags=re.IGNORECASE)
        # 12. Убираем двойные/тройные пробелы
        text = re.sub(r' +', ' ', text)
        return text

    # Латинские буквы, которые Tesseract часто путает с кириллицей при OCR русского текста.
    # Полная таблица по типичным ошибкам OCR: A→А, B→В, C→С, E→Е, H→Н, K→К, M→М, O→О, P→Р, T→Т, X→Х, Y→У,
    # a→а, c→с, e→е, p→р, o→о, x→х, y→у, N→Н, n→н, L→Л, l→л, G→Г, g→г, U→У, u→у, I→И, i→и, R→Р, r→р,
    # S→С, s→с, D→Д, d→д, b→б, W→В, w→в, F→Ф, f→ф, Z→З, z→з, V→В, v→в, J→Й, j→й, Q→Я, q→ь, h→н, k→к, m→м, t→т.
    _OCR_LATIN_TO_CYRILLIC = str.maketrans(
        "ABCEHKMOPTXYacepoxyNnLlGgUuIiRrSsDdbWwFfZzVvJjQqhkmt",
        "АВСЕНКМОРТХУасерохуНнЛлГгУуИиРрСсДдбВвФфЗзВвЙйЯьнктм"
    )

    @staticmethod
    def _is_mostly_cyrillic(text: str, threshold: float = 0.25) -> bool:
        """Определяет, преобладает ли в тексте кириллица (русский). Не применять латиница→кириллица к английским мануалам."""
        if not text or len(text.strip()) < 50:
            return False
        letters = re.findall(r'[a-zA-Zа-яА-ЯёЁ]', text)
        if not letters:
            return False
        cyrillic = sum(1 for c in letters if c in 'абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ')
        return (cyrillic / len(letters)) >= threshold

    @staticmethod
    def _normalize_ocr_russian(text: str) -> str:
        """Постобработка OCR: замена латинских букв-двойников на кириллицу (только для русского текста)."""
        if not text:
            return ""
        text = text.translate(ManualService._OCR_LATIN_TO_CYRILLIC)
        # Цифра 6 внутри слова (между буквами) часто распознаётся как «б»
        text = re.sub(r'(?<=[а-яА-Яa-zA-Z])6(?=[а-яА-Яa-zA-Z])', 'б', text)
        # Цифра 4 внутри слова иногда распознаётся как «ч»
        text = re.sub(r'(?<=[а-яА-Я])4(?=[а-яА-Я])', 'ч', text)
        # Цифра 3 между буквами часто распознаётся как «з»
        text = re.sub(r'(?<=[а-яА-Я])3(?=[а-яА-Я])', 'з', text)
        # Цифра 0 между буквами иногда распознаётся как «о»
        text = re.sub(r'(?<=[а-яА-Я])0(?=[а-яА-Я])', 'о', text)
        return text

    @staticmethod
    async def _parse_pdf_with_ocr(file_content: bytes) -> str:
        """Парсинг PDF с использованием OCR (распознавание текста из изображений)"""
        import sys
        
        try:
            import pytesseract
            from pdf2image import convert_from_bytes
            from PIL import Image
        except ImportError as e:
            raise ValueError(
                f"Для OCR требуется установить зависимости: pip install pytesseract pdf2image Pillow. "
                f"Также необходимо установить Tesseract OCR и Poppler (см. OCR_SETUP.md)"
            ) from e
        
        def _log_progress(msg: str) -> None:
            """Вывод в консоль, чтобы пользователь видел прогресс"""
            logger.info(msg)
            sys.stderr.write(msg + "\n")
            sys.stderr.flush()
        
        try:
            _log_progress("🔍 Начинаю OCR распознавание PDF...")
            
            # Конвертируем PDF в изображения (требуется poppler: brew install poppler)
            _log_progress("   Конвертация PDF в изображения (это может занять 1–2 мин)...")
            try:
                # DPI 200 быстрее; для качества можно 300
                images = convert_from_bytes(file_content, dpi=200)
            except Exception as conv_err:
                raise ValueError(
                    "Не удалось конвертировать PDF в изображения. "
                    "Установите Poppler: macOS: brew install poppler. См. OCR_SETUP.md"
                ) from conv_err
            
            total_pages = len(images)
            _log_progress(f"📄 Конвертировано {total_pages} страниц. Запускаю распознавание текста...")
            
            text_parts = []
            
            for page_num, image in enumerate(images):
                # Выводим прогресс каждую страницу
                _log_progress(f"   OCR: страница {page_num + 1}/{total_pages}...")
                
                try:
                    page_text = pytesseract.image_to_string(
                        image,
                        lang='rus+eng',
                        config='--psm 6'
                    )
                except Exception as tess_err:
                    logger.warning(f"Ошибка Tesseract на странице {page_num + 1}: {tess_err}")
                    continue
                
                if page_text:
                    text_parts.append(page_text)
            
            full_text = "\n".join(text_parts)
            _log_progress(f"✅ OCR извлек {len(full_text)} символов текста")
            # Постобработка латиница→кириллица только для русского текста (английские мануалы не портим)
            if ManualService._is_mostly_cyrillic(full_text):
                full_text = ManualService._normalize_ocr_russian(full_text)
                _log_progress("   Постобработка OCR: нормализация русских букв выполнена.")
            else:
                _log_progress("   Текст в основном латиница (англ.) — нормализация кириллицы пропущена.")
            cleaned_text = ManualService._clean_text(full_text)
            return cleaned_text if len(cleaned_text.strip()) > 50 else full_text
            
        except ValueError:
            raise
        except Exception as e:
            logger.error(f"Ошибка при OCR распознавании: {e}")
            try:
                pytesseract.get_tesseract_version()
            except Exception:
                raise ValueError(
                    "Tesseract OCR не установлен или не найден в PATH. "
                    "Установите: brew install tesseract tesseract-lang (macOS). См. OCR_SETUP.md"
                ) from e
            raise ValueError(f"Ошибка при OCR распознавании: {str(e)}") from e
    
    @staticmethod
    async def _parse_docx(file_content: bytes) -> str:
        """Парсинг DOCX файла"""
        try:
            from docx import Document
            doc_file = io.BytesIO(file_content)
            doc = Document(doc_file)
            
            text_parts = []
            for paragraph in doc.paragraphs:
                text_parts.append(paragraph.text)
            
            return "\n".join(text_parts)
        except Exception as e:
            logger.error(f"Ошибка при парсинге DOCX: {e}")
            raise ValueError(f"Ошибка при парсинге DOCX: {str(e)}")

    @staticmethod
    async def _parse_txt(file_content: bytes) -> str:
        """Парсинг TXT файла"""
        try:
            # Пробуем разные кодировки
            for encoding in ['utf-8', 'cp1251', 'latin-1']:
                try:
                    return file_content.decode(encoding)
                except UnicodeDecodeError:
                    continue
            raise ValueError("Не удалось определить кодировку файла")
        except Exception as e:
            logger.error(f"Ошибка при парсинге TXT: {e}")
            raise ValueError(f"Ошибка при парсинге TXT: {str(e)}")

    @staticmethod
    def _is_valid_chunk(chunk: str) -> bool:
        """Проверка, является ли чанк валидным (не мусором)"""
        if not chunk or len(chunk.strip()) < 10:  # Минимум 10 символов (было 20)
            return False
        
        chunk_lower = chunk.lower()
        
        # Проверяем, не состоит ли чанк ТОЛЬКО из URL-ов (более строгая проверка)
        url_count = len(re.findall(r'https?://[^\s]+|www\.[^\s]+', chunk_lower))
        # Если URL-ов больше 50% от общего количества слов/токенов
        words = chunk.split()
        if len(words) > 0 and url_count > len(words) * 0.5:
            return False
        
        # Проверяем, не состоит ли чанк из одного повторяющегося слова/фразы
        if len(words) > 3:  # Только для чанков с более чем 3 словами
            unique_words = len(set(words))
            if unique_words < len(words) / 4:  # Если уникальных слов меньше четверти (было треть)
                # Проверяем, не повторяется ли одно слово много раз
                word_counts = {}
                for word in words:
                    word_counts[word] = word_counts.get(word, 0) + 1
                max_repeats = max(word_counts.values()) if word_counts else 0
                if max_repeats > len(words) * 0.6:  # Если одно слово повторяется больше 60% (было 50%)
                    return False
        
        # Проверяем, не состоит ли чанк только из специальных символов (более мягкая проверка)
        alphanumeric_count = len(re.findall(r'[а-яёa-z0-9]', chunk_lower, re.IGNORECASE))
        if alphanumeric_count < len(chunk) * 0.2:  # Если букв/цифр меньше 20% (было 30%)
            return False
        
        return True
    
    @staticmethod
    def _split_text_into_chunks(text: str) -> List[str]:
        """Разбиение текста на чанки с перекрытием"""
        chunks = []
        start = 0
        text_length = len(text)

        while start < text_length:
            end = start + ManualService.CHUNK_SIZE
            
            # Если это не последний чанк, пытаемся разбить по предложению
            if end < text_length:
                # Ищем последнюю точку, восклицательный или вопросительный знак
                for i in range(end, max(start, end - 100), -1):
                    if text[i] in '.!?\n':
                        end = i + 1
                        break
            
            chunk = text[start:end].strip()
            if chunk:
                chunks.append(chunk)
            
            # Следующий чанк начинается с перекрытием
            start = end - ManualService.CHUNK_OVERLAP
            if start < 0:
                start = end

        return chunks

    @staticmethod
    async def get_manual(db: AsyncSession, manual_id: UUID) -> Optional[ManualOut]:
        """Получение мануала по ID"""
        manual = await ManualRepository.get_manual_by_id(db, manual_id)
        if not manual:
            return None
        return ManualOut.model_validate(manual)

    @staticmethod
    async def get_manuals_list(
        db: AsyncSession, car_id: Optional[int] = None, orphaned_only: bool = False
    ) -> List[ManualOut]:
        """Список мануалов. car_id — мануалы из глобального каталога по brand/model/year машины."""
        if car_id is not None:
            from app.repositories.car_repository import CarRepository
            car = await CarRepository.get_car_by_id(db, car_id)
            if car:
                manuals = await ManualRepository.get_manuals_by_brand_model_year(
                    db, car.brand, car.model, car.year
                )
            else:
                manuals = []
        elif orphaned_only:
            manuals = await ManualRepository.get_orphaned_manuals(db)
        else:
            manuals = await ManualRepository.get_all_manuals(db)
        return [ManualOut.model_validate(m) for m in manuals]

    @staticmethod
    async def update_manual_car(
        db: AsyncSession, manual_id: UUID, car_id: int, user_id: int
    ) -> Optional[ManualOut]:
        """Привязать мануал к автомобилю пользователя"""
        from app.repositories.car_repository import CarRepository

        car = await CarRepository.get_car_by_id(db, car_id)
        if not car or car.user_id != user_id:
            return None
        manual = await ManualRepository.update_car_id(db, manual_id, car_id)
        if not manual:
            return None
        return ManualOut.model_validate(manual)

    @staticmethod
    async def delete_manual(db: AsyncSession, manual_id: UUID) -> bool:
        """Удаление мануала и всех его чанков"""
        # Удаляем из Qdrant
        qdrant_repo = QdrantRepository()
        await qdrant_repo.delete_by_manual_id(manual_id)
        
        # Удаляем из БД (каскадно удалятся и чанки)
        return await ManualRepository.delete_manual(db, manual_id)
