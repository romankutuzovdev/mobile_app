## Auto Client (Flutter)

Мобильный клиент для твоего авто‑ассистента (VIN, мануалы, GPT).

### Структура

- `pubspec.yaml` — зависимости Flutter‑приложения.
- `lib/main.dart` — минималистичное приложение:
  - экран логина по телефону (`/auth/login`),
  - список авто (`/cars/`),
  - добавление авто по VIN (`/cars/search-vin`, `/cars/add-by-vin`),
  - чат‑экран (пока заглушка, позже привяжем к поиску по мануалам + GPT).

### Как запустить

1. Убедись, что установлен Flutter SDK и Android‑эмулятор.
2. В терминале:

```bash
cd /Users/macpro/Desktop/Artur/auto_client
flutter pub get
flutter run
```

> Если Flutter ругается на отсутствие android/ios/web, выполни **один раз**:
>
> ```bash
> cd /Users/macpro/Desktop/Artur/auto_client
> flutter create .
> ```
>
> А затем снова:
>
> ```bash
> flutter run
> ```

3. В `lib/main.dart` в классе `ApiClient` поменяй `baseUrl` на реальный адрес твоего FastAPI‑бэкенда (если он не на `localhost:8000` для эмулятора).


