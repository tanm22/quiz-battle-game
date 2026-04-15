# secrets/

Runtime secrets mounted read-only into service containers. The whole
directory is bind-mounted to `/run/secrets` in the notification container.

## firebase-admin.json (real key — gitignored)

The notification service reads this as a Firebase Admin SDK service account
to deliver FCM pushes. It is **not** committed — `.gitignore` excludes
`secrets/firebase-admin.json`. Without it, the service falls back to stub
mode (logs the push, skips FCM).

## firebase-admin.example.json (template — committed)

A placeholder JSON that documents the expected shape of the real key. Use
it as a reference; never edit it with real credentials.

## How to enable real FCM delivery

1. Open the Firebase Console → Project settings → **Service accounts**.
   https://console.firebase.google.com/project/quiz-battle-app-fd09b/settings/serviceaccounts/adminsdk
2. Click **Generate new private key** and download the JSON.
3. Save it as `secrets/firebase-admin.json` (gitignored, so this is safe).
4. Recreate the notification container so the new file is picked up:

   ```bash
   docker compose up -d --force-recreate notification
   ```

   On startup the log should switch from:

   > WARN firebase init failed: … — running in stub mode

   to:

   > [notification] Firebase Admin SDK initialized

## Never commit real credentials

The `.gitignore` rule blocks accidental commits. If you ever see
`secrets/firebase-admin.json` appear in `git status` as staged, stop and
remove it (`git rm --cached secrets/firebase-admin.json`) before committing.
