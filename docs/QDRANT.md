# Запуск Qdrant

Qdrant нужен для RAG (поиск по мануалам). Без него загрузка мануалов и поиск не работают.

## Способ 1: Скрипт (macOS, без Docker)

```bash
./scripts/run_qdrant.sh
```

Скрипт скачает бинарник Qdrant с GitHub и запустит его на http://localhost:6333.
Данные хранятся в `.qdrant_storage/`. Для обновления: `./scripts/run_qdrant.sh --update`.

## Способ 2: Docker

```bash
docker run -d -p 6333:6333 -p 6334:6334 -v $(pwd)/.qdrant_storage:/qdrant/storage qdrant/qdrant
```

## Способ 3: Docker Compose

Qdrant добавлен в `docker-compose.yml`:

```bash
docker compose up -d qdrant
```

## Проверка

```bash
curl http://localhost:6333/
```

Должен вернуть JSON с `"title":"qdrant - vector search engine"`.
