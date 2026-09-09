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

Two bot scopes. That is the whole app: no user scopes, no event
subscriptions, no interactivity, no slash commands.

| Scope              | What it is for                                                                                                                                                                                                            |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `chat:write`       | Post messages, including thread replies. This is how Bobby posts at all.                                                                                                                                                  |
| `incoming-webhook` | **Not what Bobby posts through.** It is what makes Slack's own consent screen ask _which channel_, hand that channel's id back, and add Bobby to it. Without it, OAuth yields a token and no channel, and we would have to ask you the same question again on our screen instead of Slack's. |

`incoming-webhook` is the one worth reading twice, because the name
promises more than it does here: Bobbin never posts through the webhook the
install creates. It is there so the channel choice happens on Slack's
screen rather than ours.

**Bobby cannot read your Slack.** Neither scope grants read access to any
message — in the channel he posts to or anywhere else. The scopes that
would (`channels:history` and its relatives) are not requested, and there
is no event subscription that could deliver a message to us even if one
were.

## What arrives in the channel

One incident, one thread: the verdict, the evidence behind it, a suggested
fix, and how confident Bobby is. An alert storm on the same underlying
incident folds into that one thread rather than posting again for every
alert.

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
