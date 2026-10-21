# Shortcut Account Switching Manual Validation

`apollo://reborn/account/<username>?key=<secret>` drives Apollo's real account
manager, so verify it on a device build with at least two signed-in accounts
(call them A and B). Host checks for parsing, the key comparison and the
lockout: `sh tests/run_account_switch_link_tests.sh`.

While testing, stream the tweak log (Console.app, subsystem `apollofix`) and
confirm no line ever contains the key, a full link, or a username — only
`[AccountLink]` verdicts and counts.

## Setup

- Open **Settings → Apollo Reborn → Accounts & API Keys**. Confirm the
  **Shortcut Account Switching** section shows only **Allow Account Switch
  Links**, off.
- Turn it on. Confirm **Key** (first 4 characters + •••), **Copy Key**,
  **Copy Link for…** and **Regenerate Key** appear without a reload jump.
- Tap **Key**. Confirm the full key shows and masks itself again after about
  10 seconds; tapping again while shown restarts the 10 seconds.
- Open `apollo://reborn/settings/account-switching` in Safari. Confirm Apollo
  opens Accounts & API Keys scrolled to this section.
- In Settings search, type "account switch". Confirm a **Shortcut Account
  Switching** result (opens the section) and an **Allow Account Switch Links**
  result, each listed once.

## Correct key, app running

- Make A active. **Copy Link for… → u/B**, paste it into Notes, and tap it (or
  open it from Safari).
- Confirm Apollo comes forward, the account manager flashes at most briefly
  (no slide animation), B becomes active, the success haptic plays once, and
  the toast reads **Switched to u/B**.
- Confirm the profile tab and the current feed reload as B, exactly as after a
  manual switch.
- Repeat with the username typed as `U/b`, `/u/B` and `u%2FB` in the link.

## Correct key, cold start

- Force-quit Apollo, then open the link for A.
- Confirm Apollo launches, A becomes active once the tab bar is up, and the
  **Switched to u/A** toast shows. Confirm Apollo didn't also open a native
  "user"/web page for the link.

## Already-active account

- With B active, open B's link. Confirm nothing changes and the toast reads
  **Already using u/B** (no haptic, no account manager flash).

## Rejections

Each of these must show only **Account switch link rejected** and must not
switch or open anything:

- Wrong key (change one character of the copied link).
- Missing key (delete `?key=…`).
- Feature off (turn **Allow Account Switch Links** off, open a correct link).
- Unknown username with the correct key (`…/account/nosuchuser123?key=…`).
- A link with no username (`apollo://reborn/account?key=…`).

## Busy states

- Open the account switcher (long-press the Profile tab), then trigger a
  correct link from the Shortcuts widget or Siri. Confirm it doesn't switch and
  shows **Couldn't switch accounts**; the switcher is left as it was.
- Start a compose sheet, then trigger a correct link. Confirm the same.

## Lockout

- Open a wrong-key link five times within 10 minutes. Confirm the first five
  each show the rejection toast.
- Open a correct link. Confirm nothing happens (no toast, no switch).
- Force-quit and reopen Apollo. Confirm the correct link works again.
- Separately: four wrong keys, wait just over 10 minutes from the first, then
  two more wrong keys. Confirm the correct link still works (the window slid).

## Regenerate Key

- Tap **Regenerate Key**. Confirm the alert says "Existing Shortcuts will stop
  working until you update them." Cancel changes nothing.
- Confirm **Regenerate**: the masked key changes and **New Key Created** shows.
- Open an old link: rejected. Copy a new link: it works.

## Clipboard

- After **Copy Key** / **Copy Link for…**, confirm the item is not offered on
  another device signed into the same Apple Account (local only).
- Confirm the clipboard no longer holds it after 10 minutes.

## Backup & Restore

- With the feature on, **Backup Settings**. Unzip the backup and confirm
  `keychain.plist` has no `com.christianselig.Apollo.accountswitch` entry and
  no file contains the key.
- Note the masked key, then **Restore Settings** from that backup and relaunch.
- Confirm the feature is still on and **Key** shows a different key; old links
  are rejected and newly copied links work.

## Shortcuts app

- In Shortcuts, create a shortcut: **Choose from Menu** with items "A" and "B";
  under each, **Open URLs** with that account's copied link.
- Run it from the Shortcuts app, from a Home Screen icon, and with Siri.
  Confirm each item switches to its account (or shows **Already using…**).
- Run it with Apollo force-quit. Confirm the cold-start switch works.
