require 'slack-ruby-bot'
require 'net/http'
require 'uri'
require 'json'
require 'openssl'
require 'yaml'

$config = YAML.load_file('config.yaml') # Load for all secret keys and tokens

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

# Our methods

def refreshtoken(refreshtoken)
  # Refreshes the token, needs to be called every hour, given the refreshtoken OR every time the perms bot command is called
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
  puts "#{response} in #{__method__}"
  json = JSON.parse(response.body)
  access_token = json["access_token"]
  return access_token
end


def invite_user(accesstoken, redditUser, slug, permissions)
  # Invites a user to a specified live thread, and sets specific permissions
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
  puts "#{response.body} in #{__method__}"
end

def lead_user(accesstoken, redditUser, slug)
  # Check if user is already a contributor, if so, update perms, if not, invite with full perms

  uri = URI.parse("https://www.oauth.reddit.com/api/live/#{slug}/contributors/")

  request = Net::HTTP::Get.new(uri.path)

  request.add_field("Authorization", "bearer #{accesstoken}") # Uses our access token for OAuth2
  #request.add_field("Content-Type", "application/json")

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(request)
  end

  responseparsed = JSON.parse(response.body)
  contributors = []
  responseparsed.each do |row|
    row["data"]["children"].each do |child|
      contributors << child['name']
    end
  end

  permissions = "+update,+edit,+manage,+close,+settings,+invite" # Full perms

  # This gives us a list of contributors so we can check if the redditUser is there
  if contributors.include? redditUser # If the user is already a contributor
    puts "#{redditUser} is already a contributor, updating permissions"
    update_perms(accesstoken, redditUser, slug, permissions) # Then make that user the lead (give all perms)
  else
    puts "#{redditUser} is not a contributor, inviting with full perms"
    invite_user(accesstoken, redditUser, slug, permissions)
  end
end

def update_perms(accesstoken, redditUser, slug, permissions)
  # Updates the permissions for a contributor
  uri = URI.parse("https://www.oauth.reddit.com/api/live/#{slug}/set_contributor_permissions")

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
  puts "#{response} in #{__method__}"
end

# Slack bot part

SlackRubyBot::Client.logger.level = Logger::WARN

class Perms < SlackRubyBot::Bot

  refreshtoken = $config["refresh_token"]

  command 'add' do |client, data, msg| # livebot add <slug> <user> <perms>
    puts "Got an add command."
    msg = msg.to_s.match(/.* (.*?) (.*) (.*)/)
    slug = msg[1]
    redditUser = msg[2]
    permissions = msg[3]
    puts "Thread: #{slug}"
    puts "User: #{redditUser}"
    accesstoken = refreshtoken(refreshtoken)
    sleep 6 # implement as an error exception for 429 so we only sleep when it fails
    invite_user(accesstoken, redditUser, slug, permissions)
  end

  command 'lead' do |client, data, msg| # livebot lead <slug> <user>
    puts "Got a lead command."
    msg = msg.to_s.match(/.* (.*?) (.*)/)
    slug = msg[1]
    redditUser = msg[2]
    puts "Thread: #{slug}"
    puts "User: #{redditUser}"
    accesstoken = refreshtoken(refreshtoken)
    sleep 6 # implement as an error exception for 429 so we only sleep when it fails
    lead_user(accesstoken, redditUser, slug)
  end
end

Perms.run
