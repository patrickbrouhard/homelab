# Role: notify_telegram

Envoie un message via l'API Telegram.

## Variables obligatoires (vault recommandé)

- `telegram_token` : Token du bot
- `telegram_chat_id` : ID du chat

## Variables optionnelles

| Variable | Défaut | Description |
|--------|--------|------------|
| telegram_message | "" | Message à envoyer |
| telegram_parse_mode | Markdown | Mode de formatage |
| telegram_retries | 3 | Nombre de tentatives |
| telegram_delay | 2 | Délai entre retries |
| telegram_timeout | 10 | Timeout HTTP |
| telegram_enabled | true | Active/désactive le rôle |

## Exemple

```yaml
- hosts: all
  roles:
    - role: notify_telegram
      vars:
        telegram_message: "Déploiement terminé ✅"