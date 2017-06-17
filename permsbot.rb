require 'slack-ruby-bot'
require 'net/http'
require 'uri'
require 'json'
require 'openssl'
require 'yaml'

$config = YAML.load_file('config.yaml') # Load for all secret keys and tokens

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
def refreshtoken(refreshtoken) # Refreshes the token, needs to be called every hour, given the refreshtoken OR every time the perms bot command is called
  uri = URI.parse("https://www.reddit.com/api/v1/access_token")
  request = Net::HTTP::Post.new(uri)
  request.basic_auth($config["client_id"], $config["client_secret"]) # client_id, client_secret
  request.set_form_data(
    "grant_type" => "refresh_token",
    "refresh_token" => refreshtoken,
    "redirect_uri" => "http://localhost",
  )

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
    tries = 0
    begin
      http.request(request)
    rescue Net::HTTPTooManyRequests => error
      tries += 1
      if tries < 3
        puts "#{error.message}"
        sleep(10)
        retry
      else
        puts "Exiting after 3 attemps"
        abort
      end
    end
  end
  puts response
  json = JSON.parse(response.body)
  access_token = json["access_token"]
  return access_token
end


def invite_user(accesstoken, redditUser, slug, permissions) # Invites a user to a specified live thread, and sets specific permissions
  uri = URI.parse("https://www.oauth.reddit.com/api/live/#{slug}/invite_contributor/")

  request = Net::HTTP::Post.new(uri.path)

  request.add_field("Authorization", "bearer #{accesstoken}") # Uses our access token for OAuth2
  request.add_field("Content-Type", "application/json")

  request.form_data = {
    "api_type" => "json",
    "name" => redditUser,
    "permissions" => permissions,
    "type" => "liveupdate_contributor_invite"
  }

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(request)
  end
  puts response
end

def lead_user(accesstoken, redditUser, slug) # Gives a user all permissions
  uri = URI.parse("https://www.oauth.reddit.com/api/live/#{slug}/invite_contributor/")

  request = Net::HTTP::Post.new(uri.path)

  request.add_field("Authorization", "bearer #{accesstoken}") # Uses our access token for OAuth2
  request.add_field("Content-Type", "application/json")

  request.form_data = {
    "api_type" => "json",
    "name" => redditUser,
    "permissions" => "+update,+edit,+manage,+close,+settings,+invite",
    "type" => "liveupdate_contributor_invite"
  }

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(request)
  end
  puts response
end

SlackRubyBot::Client.logger.level = Logger::WARN
SLACK_API_TOKEN = "xoxb-196940761536-tjTuUeTiXZioYTnwuADLEFsc"
class Perms < SlackRubyBot::Bot
  refreshtoken = $config["refresh_token"]
  command 'add' do |client, data, msg| # livebot add <slug> <user> <perms>
    puts "Got an add command."
    msg = msg.to_s.match(/.* (.*?) (.*) (.*)/)
    slug = msg[1]
    redditUser = msg[2]
    permissions = msg[3]
    puts slug
    puts redditUser
    accesstoken = refreshtoken(refreshtoken)
    invite_user(accesstoken, redditUser, slug, permissions)
  end
  command 'lead' do |client, data, msg| # livebot lead <slug> <user>
    puts "Got a lead command."
    msg = msg.to_s.match(/.* (.*?) (.*)/)
    slug = msg[1]
    redditUser = msg[2]
    puts slug
    puts redditUser
    accesstoken = refreshtoken(refreshtoken)
    lead_user(accesstoken, redditUser, slug)
  end
end

Perms.run
