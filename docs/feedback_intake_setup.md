# Приём фидбека из Discord в таски (SCRUM-362 → триаж PM)

Вебхук ПИШЕТ фидбек в Discord, но читать его не может. Чтобы PM забирал фидбек и
заводил таски, нужен **Discord-бот с правом чтения** канала фидбека.

## Настройка бота (один раз)
1. https://discord.com/developers/applications → **New Application** (имя «FantasyDisk Intake»).
2. Вкладка **Bot** → **Add Bot** → **Reset Token** → скопировать токен.
3. Вкладка **Bot** → включить **Message Content Intent** (нужно для чтения текста).
4. Пригласить бота на сервер: вкладка **OAuth2 → URL Generator** → scopes `bot`,
   права **Read Messages/View Channels** + **Read Message History** → открыть URL,
   выбрать свой сервер.
5. Дать боту доступ к каналу фидбека (если канал приватный — добавить роль бота).
6. Сохранить токен в Keychain (НЕ в репозиторий):
   `security add-generic-password -s fantasydisk-discord-bot -a fantasydisk -w '<BOT_TOKEN>'`

## Использование
- `python3 tools/feedback_intake.py` — забрать НОВЫЕ фидбеки (дедуп по last_seen),
  скачать вложения в `build/feedback_intake/<id>/`, вывести JSON.
- `--all` — перечитать последние N (limit) без учёта last_seen; `--limit N`.
- PM триажит вывод: осмысленные баги/идеи → заводит `.md`-таск + Jira + диспатч
  воркеру; спам/мусор → пропускает.

## Безопасность
- Bot-токен — секрет (в Keychain, не в git). Если утёк — Reset Token в Dev Portal.
