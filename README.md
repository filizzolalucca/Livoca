<p align="center">
  <img src="assets/icon/icon.png" alt="Livoca icon" width="120">
</p>

<h1 align="center">Livoca 🐼💖</h1>

<p align="center">
  A simple personal organizer built with Flutter. Everything is stored on the phone, with no backend.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS-lightgrey" alt="Platforms">
</p>

> The app's interface is in Brazilian Portuguese.

## Features

- **Onboarding**: on first launch the user enters their name and age (editable later from the profile icon).
- **Today's date** always visible at the top of the main screen.
- **Completed tasks counter** with a filter: Day, Week, Month, Quarter, Semester, Year or All time.
- **Daily briefing**: the first time the app is opened each day, it shows today's tasks and appointments (thinking panda), followed by the tasks that weren't finished in time (sad panda).
- **Tasks by period**: Today, This week, This month, This quarter, This semester and This year.
- **Tasks and calendar in one place**: tasks and appointments are the same thing.
  - A task **without a set day** shows up on the calendar **spanning the whole period** (a strip below the days).
  - An item **with a specific day** (and optional time) shows up on that day in the calendar and also in the task list, in the smallest row that contains that day (e.g. Friday this week → "This week"; on the day itself → "Today").
  - Anything created from the calendar also becomes a task, unless **"Show in task list"** is turned off. This can be changed at any time by editing the item.
  - Dates after the current year go to **"Later on"**.
- **Confetti celebration**: when every task in a period is done, a congratulations screen with the panda appears, and the image can be **shared** to other apps.
- **Missed**: tasks not completed by their deadline move to this section.
- **Paused**: tasks can be put on hold.
- **Drag and drop**: drag a task by its **⠿** handle or **long-press** it. A panel with every destination (Day, Week, Month, Quarter, Semester, Year and Pause) appears at the top, and the list **auto-scrolls** when your finger nears the edge. Dropping a paused or missed task into a row resumes it in that period. Each task's `⋮` menu offers the same options.

## Updating without losing data

Data lives on the device. If a version is already installed, just install the new APK over it: the app keeps everything, and appointments from v1 are converted automatically. For this to work, every APK must be **signed with the same key** and have a higher `version` in `pubspec.yaml`.

## Tech stack

| | |
|---|---|
| Framework | Flutter (Material, pt-BR localization) |
| Persistence | `shared_preferences` |
| Calendar | `table_calendar` |
| Extras | `confetti`, `share_plus`, `flutter_svg`, `intl` |

## Getting started

```bash
flutter pub get
flutter run
```

## Project structure

```
lib/
  main.dart                    # startup, theme, pt-BR locale
  models.dart                  # periods, tasks, appointments, profile
  app_state.dart               # state and persistence (shared_preferences)
  app_scope.dart               # access to state through the widget tree
  theme.dart                   # pink color palette
  screens/
    onboarding_screen.dart     # name and age
    daily_briefing_screen.dart # daily summary
    home_shell.dart            # Tasks / Calendar navigation
    tasks_screen.dart          # period rows and drag and drop
    celebration_screen.dart    # confetti and sharing
    agenda_screen.dart         # calendar and appointments
  widgets/
    panda.dart
    task_widgets.dart
```

## Image credits

The panda illustrations are **public domain (CC0)** from [OpenClipart](https://openclipart.org):

- [Cute Cartoon Panda](https://openclipart.org/detail/279984/cute-cartoon-panda): `assets/images/panda.svg` (also used for the app icon)
- [Panda with a Heart](https://openclipart.org/detail/300655/panda-with-a-heart): `assets/images/panda_heart.svg`
- [Sad Panda](https://openclipart.org/detail/312494/sad-panda): `assets/images/panda_sad.svg`
- `assets/images/panda_thinking.svg`: derived from "Cute Cartoon Panda", with a checklist speech bubble added

## Author

**Lucca Filizzola** · [@filizzolalucca](https://github.com/filizzolalucca)
