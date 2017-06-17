To install,

```
git clone
gem install bundler
bundle install
```

Then, create a YAML file called `config.yaml` and place your keys in it like so:

```
slack_token: Slack API key
refresh_token: Refresh Token
client_id: Client ID
client_secret: Secret Key
```
With the client_id and secret_key coming from your Reddit app, and the refresh_token coming from your Reddit OAuth response.

To run,

```
bundle exec ruby permsbot.rb
```
