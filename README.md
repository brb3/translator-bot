# Translator Bot

This is a really stupid simple translation bot for Mastodon.

See it in action here: [@japanesetranslator](https://mastodon.cloud/@japanesetranslator)

It works by pulling the latest toots from the federated timeline, passing
them through the Azure Translation API, then replying to the original toot_id.

Requires a `secret.json` which contains API keys for Azure and a Mastodon
instance.

It needs a bit of work to run consistently - it sometimes gets a bit tripped up
and needs to be restarted.
