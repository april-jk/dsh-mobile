---
name: Account deletion and legal compliance
about: Track the account lifecycle and store-submission requirements
title: "feat: add account deletion and release compliance surfaces"
labels: compliance, account
---

## Problem

The app supports account creation but only provides local sign-out. A public mobile-store release needs an in-app account deletion flow and published privacy disclosures.

## Acceptance criteria

- Add an authenticated Relay endpoint that permanently deletes the account and its devices, refresh tokens, pairing records, and access history.
- Add an explicit destructive confirmation flow under Settings.
- Re-authenticate or otherwise verify recent account ownership before deletion.
- Revoke active mobile and computer sessions immediately after deletion.
- Publish Privacy Policy and Terms URLs and expose them from registration and Settings.
- Complete Apple privacy labels and Google Play Data safety declarations from the documented data inventory.
- Add integration tests proving deletion removes server data and prevents token reuse.

## Release impact

Block public App Store and Google Play submission until this issue is complete. Internal testing may continue with test accounts and documented data-retention expectations.
