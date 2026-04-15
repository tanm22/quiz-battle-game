# secrets/

Runtime secrets mounted read-only into service containers.

## firebase-admin.json

The notification service (Go) reads this as a Firebase Admin SDK service
account to deliver FCM pushes. The file checked into git is a **placeholder**
— replace it with a real service account JSON to enable push delivery.

### How to generate a real key

1. Open the Firebase Console → Project settings → **Service accounts**.
   https://console.firebase.google.com/project/quiz-battle-app-fd09b/settings/serviceaccounts/adminsdk
2. Click **Generate new private key** and download the JSON.
3. Save it over `secrets/firebase-admin.json` in this repo.
4. Rebuild the notification service so the new file is picked up:

   ```bash
   docker compose up -d --force-recreate notification
   ```

   On startup the log should switch from:

   > WARN GOOGLE_APPLICATION_CREDENTIALS not set — running in stub mode

   to:

   > [notification] Firebase Admin SDK initialized

### Never commit real credentials

Before `git commit`, double-check `git diff secrets/firebase-admin.json`.
If you see a `private_key` field, you have real credentials staged — revert
the change (`git checkout secrets/firebase-admin.json`) and keep the key
local-only.
