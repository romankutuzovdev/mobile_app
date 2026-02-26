from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional, List
from uuid import UUID
import io
import logging
import re

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
    async def upload_manual(
        db: AsyncSession,
        file_content: bytes,
        filename: str,
        title: str,
        car_id: Optional[int] = None,
        use_ocr_for_pdf: bool = False
    ) -> ManualOut:
        """Загрузка и обработка мануала. use_ocr_for_pdf=True — для PDF сразу OCR по всем страницам."""
        # Создаем запись мануала в БД
        manual = await ManualRepository.create_manual(
            db=db,
            title=title,
            source_file=filename,
            car_id=car_id
        )

        # Парсим файл в текст: при use_ocr_for_pdf для PDF сразу OCR, иначе обычный парсинг
        if use_ocr_for_pdf and filename.lower().endswith(".pdf"):
            print("📄 Режим: принудительный OCR по всему PDF (все страницы)...", flush=True)
            text_content = await ManualService._parse_pdf_with_ocr(file_content)
        else:
            text_content = await ManualService._parse_file(file_content, filename)
        
        if not text_content:
            raise ValueError("Не удалось извлечь текст из файла")

        # Разбиваем на чанки
        print("📄 Разбиваю текст на чанки...", flush=True)
        chunks = ManualService._split_text_into_chunks(text_content)
        
        # Фильтруем пустые и мусорные чанки
        valid_chunks = []
        for chunk in chunks:
            if ManualService._is_valid_chunk(chunk):
                valid_chunks.append(chunk)
            else:
                logger.warning(f"Пропущен мусорный чанк: {chunk[:100]}...")
        
        total_valid = len(valid_chunks)
        logger.info(f"Из {len(chunks)} чанков валидных: {total_valid}")
        print(f"✅ Валидных чанков: {total_valid}. Начинаю загрузку в векторную БД (это может занять несколько минут)...", flush=True)
        
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
                    car_id=car_id,
                    page=None,
                    title=title,
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
                # Прогресс в консоль каждые 10 чанков или на последнем
                if (i + 1) % 10 == 0 or (i + 1) == total:
                    print(f"   Чанк {i+1}/{total} обработан...", flush=True)
            except Exception as e:
                logger.error(f"Ошибка при обработке чанка {i+1}: {e}")
                continue

        print(f"✅ Готово: загружено {total} чанков.", flush=True)
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
            logger.info("📄 Пробую парсинг через pdfplumber...")
            
            pdf_file = io.BytesIO(file_content)
            text_parts = []
            
            with pdfplumber.open(pdf_file) as pdf:
                logger.info(f"📄 Парсинг PDF: {len(pdf.pages)} страниц")
                
                for page_num, page in enumerate(pdf.pages):
                    page_text = page.extract_text()
                    if page_text:
                        text_parts.append(page_text)
                        # Логируем первые 200 символов первых страниц для отладки
                        if page_num < 3:
                            logger.debug(f"   Страница {page_num + 1}: {page_text[:200]}...")
            
            full_text = "\n".join(text_parts)
            logger.info(f"📊 Исходный текст (pdfplumber): {len(full_text)} символов")
            
        except ImportError:
            logger.warning("⚠️  pdfplumber не установлен, использую PyPDF2...")
            # Fallback на PyPDF2
            try:
                import PyPDF2
                pdf_file = io.BytesIO(file_content)
                pdf_reader = PyPDF2.PdfReader(pdf_file)
                
                logger.info(f"📄 Парсинг PDF: {len(pdf_reader.pages)} страниц")
                
                text_parts = []
                for page_num, page in enumerate(pdf_reader.pages):
                    page_text = page.extract_text()
                    if page_text:
                        text_parts.append(page_text)
                        if page_num < 3:
                            logger.debug(f"   Страница {page_num + 1}: {page_text[:200]}...")
                
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
                
                text_parts = []
                for page in pdf_reader.pages:
                    page_text = page.extract_text()
                    if page_text:
                        text_parts.append(page_text)
                
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
        cleaned_text = ManualService._clean_text(full_text)
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
            print(msg, flush=True)
        
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
    async def get_manuals_list(db: AsyncSession) -> List[ManualOut]:
        """Список всех мануалов"""
        manuals = await ManualRepository.get_all_manuals(db)
        return [ManualOut.model_validate(m) for m in manuals]

    @staticmethod
    async def delete_manual(db: AsyncSession, manual_id: UUID) -> bool:
        """Удаление мануала и всех его чанков"""
        # Удаляем из Qdrant
        qdrant_repo = QdrantRepository()
        await qdrant_repo.delete_by_manual_id(manual_id)
        
        # Удаляем из БД (каскадно удалятся и чанки)
        return await ManualRepository.delete_manual(db, manual_id)
