# FastAPI JWT Authentication Project

Полнофункциональный проект FastAPI с JWT авторизацией, использующий async/await паттерны.

## Технологии

- **FastAPI** - современный веб-фреймворк
- **Python 3.11** - язык программирования
- **SQLAlchemy async 2.0** - асинхронный ORM
- **PostgreSQL** - база данных
- **Alembic** - миграции БД
- **Pydantic v2** - валидация данных
- **passlib[bcrypt]** - хеширование паролей
- **python-jose** - работа с JWT токенами
- **Docker & docker-compose** - контейнеризация

## Структура проекта

```
app/
    main.py              # Точка входа приложения
    config.py            # Конфигурация (Settings)
    database.py          # Настройка БД (async engine + session)
    
    auth/                # Модуль авторизации
        router.py        # API эндпоинты
        service.py       # Бизнес-логика
        schemas.py       # Pydantic схемы
        models.py        # SQLAlchemy модели
        utils.py         # Утилиты (get_current_user)
    
    users/               # Модуль пользователей
        router.py        # API эндпоинты
        service.py       # Бизнес-логика
        schemas.py       # Pydantic схемы
        models.py        # SQLAlchemy модели
    
    core/                # Ядро приложения
        security.py      # JWT и хеширование паролей
        exceptions.py    # Кастомные исключения

alembic/                 # Миграции БД
docker-compose.yml       # Docker Compose конфигурация
Dockerfile               # Docker образ
pyproject.toml           # Зависимости проекта
.env                     # Переменные окружения
```

## API Эндпоинты

### Авторизация (`/auth`)

- `POST /auth/register` - Регистрация нового пользователя
- `POST /auth/login` - Вход и получение токенов
- `POST /auth/refresh` - Обновление access token
- `GET /auth/me` - Информация о текущем пользователе (требует авторизации)
- `POST /auth/logout` - Выход (удаление refresh token)

### Пользователи (`/users`)

- `GET /users/` - Список пользователей (требует авторизации)
- `GET /users/{user_id}` - Информация о пользователе (требует авторизации)

## JWT Токены

- **Access Token**: срок действия 15 минут, алгоритм HS256
- **Refresh Token**: срок действия 30 дней, алгоритм HS256
- Ключ шифрования берется из переменной окружения `SECRET_KEY`

## Установка и запуск

### Локальная разработка

1. **Клонируйте репозиторий и перейдите в директорию проекта**

2. **Создайте виртуальное окружение**
```bash
python3.11 -m venv venv
source venv/bin/activate  # На Windows: venv\Scripts\activate
```

3. **Установите зависимости**

Через pip (рекомендуется):
```bash
pip install -r requirements.txt
```

Или через Poetry:
```bash
pip install poetry
poetry install
```

4. **Создайте файл `.env`** (скопируйте из `.env.example` и заполните)
```bash
cp .env.example .env
```

5. **Запустите PostgreSQL** (или используйте Docker)
```bash
docker-compose up -d db
```

6. **Примените миграции**
```bash
alembic upgrade head
```

7. **Запустите приложение**
```bash
uvicorn app.main:app --reload
```

Приложение будет доступно по адресу: http://localhost:8000

### Docker Compose

1. **Создайте файл `.env`**
```bash
cp .env.example .env
```

2. **Запустите все сервисы**
```bash
docker-compose up -d
```

3. **Примените миграции** (в контейнере web)
```bash
docker-compose exec web alembic upgrade head
```

Приложение будет доступно по адресу: http://localhost:8000

## Использование API

### Регистрация пользователя

```bash
curl -X POST "http://localhost:8000/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "username": "testuser",
    "password": "password123"
  }'
```

### Вход

```bash
curl -X POST "http://localhost:8000/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }'
```

Ответ:
```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "token_type": "bearer"
}
```

### Получение информации о текущем пользователе

```bash
curl -X GET "http://localhost:8000/auth/me" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Обновление токена

```bash
curl -X POST "http://localhost:8000/auth/refresh" \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token": "YOUR_REFRESH_TOKEN"
  }'
```

## Документация API

После запуска приложения доступна интерактивная документация:

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## Переменные окружения

Основные переменные в `.env`:

- `DATABASE_URL` - URL подключения к PostgreSQL
- `SECRET_KEY` - секретный ключ для JWT (обязательно измените в продакшене!)
- `ACCESS_TOKEN_EXPIRE_MINUTES` - срок действия access token (по умолчанию 15)
- `REFRESH_TOKEN_EXPIRE_DAYS` - срок действия refresh token (по умолчанию 30)
- `DEBUG` - режим отладки (True/False)

## Миграции

Создание новой миграции:
```bash
alembic revision --autogenerate -m "Описание изменений"
```

Применение миграций:
```bash
alembic upgrade head
```

Откат миграции:
```bash
alembic downgrade -1
```

## Лицензия

MIT

