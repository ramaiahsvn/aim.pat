# User Memory — aim.pat

> Profile and preferences for the primary user of this platform.
> Update when preferences are confirmed or corrected.

## Identity

- Username: `bnprs`
- Email: `ramaiah.polyu@gmail.com`
- Git user: `ramaiahsvn`

## Working Style

- Direct and concise — no long explanations unless asked
- Prefers to be shown findings before destructive actions are taken
- Comfortable delegating decisions (e.g. role selection) but wants confirmation before commit/push
- Expects Claude to follow CLAUDE.md startup protocol strictly every session

## Email Formatting (all outbound emails)

- **Format:** HTML — never plain text
- **Font:** `'Segoe UI', Arial, sans-serif`
- **Body font size:** 15px, line-height 1.6
- **Table / detail font size:** 14px
- **Max width:** 620px, centred, padding 24px
- **Sign-off:** Regards,\nRamaiah (bold name)
- **Always show draft before sending — never send autonomously**

## Platform Usage Patterns

- Works across multiple agent groups; selects group and agent at session start
- Prefers agents to be initialized into sub-sessions before working with them
- Reviews credentials and secrets carefully; security-conscious

## Credentials & Environment

- AWS profiles in use: `itp` (us-east-2), `bnprs` (ap-south-2), `gitlab`
- Claude auth: OAuth (no static ANTHROPIC_API_KEY)
- Shell secrets sourced from: `secrets/shell-exports.sh` (git-ignored)
- Full credential map: `secrets/credentials-map.yaml`
