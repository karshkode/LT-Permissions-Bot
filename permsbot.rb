require 'slack-ruby-bot'
require 'net/http'
require 'uri'
require 'json'
require 'openssl'
require 'yaml'
require './modules.rb'

$config = YAML.load_file('config.yaml') # Load for all secret keys and tokens

SlackRubyBot::Client.logger.level = Logger::WARN

class Perms < SlackRubyBot::Bot

  refreshtoken = $config["refresh_token"]

  command 'add' do |client, data, msg| # livebot add <slug> <user> <perms>
    puts "\nGot an add command."
    userid = data["user"] # User ID of command sender
    msg = msg.to_s.match(/.* (.*?) (.*) (.*)/)
    slug = msg[1]
    redditUser = msg[2]
    permissions = msg[3]
    puts "Thread: #{slug}"
    puts "User: #{redditUser}"
    accesstoken = Permissions.refreshtoken(refreshtoken)
    sleep 3 # implement as an error exception for 429 so we only sleep when it fails
    Permissions.invite_user(accesstoken, redditUser, slug, permissions)
  end

  command 'lead' do |client, data, msg| # livebot lead <slug> <user>
    puts "\nGot a lead command."
    userid = data["user"] # User ID of command sender
    msg = msg.to_s.match(/.* (.*?) (.*)/)
    slug = msg[1]
    redditUser = msg[2]
    puts "Thread: #{slug}"
    puts "User: #{redditUser}"
    accesstoken = Permissions.refreshtoken(refreshtoken)
    sleep 3
    Permissions.lead_user(accesstoken, redditUser, slug)
  end
end

Perms.run
