# Connecting Bobbin to Slack

Bobby posts into **your** Slack workspace. You install the Bobbin app
yourself, from your own console, on Slack's own consent screen — and you
pick the channel investigations land in while you are there.

## Install

In the Bobbin console, choose **Add to Slack**.

You land on Slack's own consent screen, which asks which workspace and
which channel. Approve it, and Slack sends the resulting token straight to
Bobbin. Nothing to copy, nothing to paste, and no credential passing
through a person at either end. Bobby joins the channel you picked as part
of the same step, so there is no separate `/invite`.

## What the app asks for, and why

Six bot scopes, one event subscription, and interactivity switched on. No
user scopes and no slash commands. Every permission, and what each one is
actually for:

| Scope               | What it is for                                                                                                                                                                                                                                                                                                  |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `chat:write`        | Post messages, including thread replies. The one he uses most.                                                                                                                                                                                                                                                  |
| `incoming-webhook`  | **Not what Bobby posts through.** Asked for at install only, to get a channel: it is what makes Slack's own consent screen ask _which channel_, hand that channel's id back, and add Bobby to it. Without it, OAuth yields a token and no channel, and we would have to ask you the same question again on our screen instead of Slack's. |
| `app_mentions:read` | **The one that reads.** It delivers the messages that **name him**, and nothing else, which is what lets you ask him a follow-up in a thread. Following a thread unprompted would need `channels:history` — _read every message in the channel_ — and we do not ask for it.                                       |
| `channels:read`     | List your public channels, so choosing where a project posts is a list rather than a channel id you have to find.                                                                                                                                                                                              |
| `chat:write.public` | Post to a public channel he has not been invited to. Without it, choosing a channel would only work if somebody remembered to invite him, and the failure would be silent.                                                                                                                                       |
| `groups:read`       | The private channels he **has already been invited to**, so those can be chosen too. Narrower than it sounds: it cannot see a private channel he is not in.                                                                                                                                                      |

`incoming-webhook` is the one worth reading twice, because the name
promises more than it does here: Bobbin never posts through the webhook the
install creates. It is there so the channel choice happens on Slack's
screen rather than ours.

**Bobby cannot read an ordinary message in your channel.** The one scope
that reads, `app_mentions:read`, is delivered through an Events API
subscription for `app_mention` — so a conversation between you and a
colleague under one of his cards reaches him only if somebody types his
name in it. He reads nothing until somebody mentions him.

This page said something stronger until 2026-09-11 — two scopes, no
events, no interactivity, and that he reads nothing at all — and that
stopped being true when follow-up questions shipped. Corrected here on
2026-09-15 rather than quietly reworded; the product's own
[Slack page](https://docs.getbobbin.dev/connect/slack/) had said so since
the change.

**Interactivity is switched on**, which is a different thing and worth
separating: it is what lets the buttons on a card come back to us. Slack
sends us the click — which button, on which card, and which user pressed
it — and nothing else in the channel. A click is something a person hands
over deliberately; it is not a read. Those requests carry Slack's own
signature, and that signature is the whole of their authentication.

## What arrives in the channel

One incident, one thread: the verdict, the evidence behind it, a suggested
fix, and how confident Bobby is. An alert storm on the same underlying
incident folds into that one thread rather than posting again for every
alert. Mention him in that thread and he answers there, from the
investigation that already ran plus a small, bounded budget for new reads.

## Changing the channel

The channel is chosen once, on Slack's consent screen, at install time.
Running **Add to Slack** again lets you pick a different one.

## Removing Bobby

In your workspace: **Settings → Manage apps → Bobbin → Remove App**. The
token dies with it and Bobbin loses all Slack access immediately — there is
nothing to ask us to revoke.

You do not have to do it for the connection to end. When you leave, Bobbin
uninstalls the app itself rather than merely forgetting the token, on its
own schedule and without waiting for you. Either half alone is sufficient.
