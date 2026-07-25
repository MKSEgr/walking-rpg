# Walking RPG Mobile

Flutter shell первоначального приложения.

## Почему нет каталогов `android/` и `ios/`

Они генерируются локально установленной версией Flutter. Это позволяет использовать актуальные шаблоны Gradle/Xcode вместо хранения устаревшего generated-кода в стартовом архиве.

## Создание host-проектов

```bash
flutter create --platforms=android,ios --org com.walkingrpg --project-name walking_rpg_mobile .
flutter pub get
flutter run
```

## Текущий экран

Главный экран работает на локальном demo snapshot и показывает:

- дневную цель;
- энергию;
- экспедицию;
- пилота;
- питомца;
- границу следующей интеграции с реальными шагами.

## Следующий шаг

Подключить datasource активности и заменить demo snapshot ответом Java backend.
