# Connecting Bobbin to Slack

Bobby posts into **your** Slack workspace, so the app is installed by you,
in your workspace, with a token you control. We never need access to your
Slack beyond the one channel you point us at.

Four steps, all yours. The last one hands us two values.

## 1. Create the app from the manifest

At <https://api.slack.com/apps> → **Create New App → From a manifest**,
choose your workspace, and paste:

```yaml
display_information:
  name: Bobbin
  description: Investigates your Cloud Monitoring alerts and posts a root-cause hypothesis with evidence.
  background_color: '#212a31'
features:
  bot_user:
    display_name: bobby
    always_online: true
oauth_config:
  scopes:
    bot:
      - chat:write
settings:
  org_deploy_enabled: false
  socket_mode_enabled: false
  token_rotation_enabled: false
```

That is the whole app: **one bot user, one scope**. `chat:write` lets
Bobby post messages, including thread replies. There are no event
subscriptions, no interactivity, and no slash commands — Bobby cannot read
your Slack, only write to the channel you invite it to.

## 2. Install it and copy the token

**Install App → Install to Workspace → Allow**, then copy the **Bot User
OAuth Token** — it starts `xoxb-`.

This token is a credential for your workspace. Treat it accordingly; step
4 covers getting it to us safely.

## 3. Choose a channel and invite Bobby

Create or pick the channel where investigations should land, then in that
channel:

```text
/invite @bobby
```

**This step is not optional.** Posting to a channel the bot has not been
invited to fails with `not_in_channel`, and the failure is silent from
your side.

Then copy the channel ID: **channel name → About → Channel ID**, starting
with `C`.

## 4. Send us the token and the channel ID

We need both to finish the connection:

- the `xoxb-…` bot token from step 2
- the `C…` channel ID from step 3

**Do not email them or paste them in a chat.** Ask us for a one-time
secret link and send them through that; we will have already offered one.
The channel ID alone is harmless — it is the token that matters.

Once we have them, Bobby posts into the channel the next time one of your
alerts fires.

## Why this is manual, and what replaces it

An "Add to Slack" button would be better: you would click once, and the
token would go straight from Slack to us without a human ever handling it.
That is where this is going.

It is manual today because the button needs a verified public app, and we
would rather have five design partners tell us Bobbin is useful before
asking Slack to review it. Until then, the manifest above is the whole app
and you can read every permission it requests.

## Removing Bobby

Delete the app from your workspace (**Settings → Manage apps → Bobbin →
Remove App**). The token dies with it and we lose all Slack access
immediately — there is nothing to ask us to revoke.
