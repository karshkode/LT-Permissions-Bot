To install,

```
git clone
gem install bundler
bundle install
```

Then, create a YAML file called `config.yaml` and place your keys in it like so:

```
refresh_token: Refresh Token
client_id: Client ID
client_secret: Secret Key
```
With the client_id and secret_key coming from your Reddit app, and the refresh_token coming from your Reddit OAuth response.

To run,

```
SLACK_API_TOKEN = ... bundle exec ruby permsbot.rb
```

With ... obviously being replaced by your Slack API token.