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

  command 'join' do |client, data, msg| # livebot join <slug> <user>
    puts "\nGot a join command."
    userid = data["user"] # User ID of command sender
    if Permissions.user_check(userid) == true # If the user is not on the list of contributors already
      # Write into whitelist["contributors"] and append thread ID
      # This will serve as a temporary list of contribs for this particular thread - data-tracking!
      msg = msg.to_s.match(/.* (.*?) (.*)/)
      slug = msg[1]
      redditUser = msg[2]
      puts "Thread: #{slug}"
      puts "User: #{redditUser}"
      accesstoken = Permissions.refreshtoken(refreshtoken)
      sleep 3 # implement as an error exception for 429 so we only sleep when it fails
      Permissions.invite_user(accesstoken, redditUser, slug, "-all")
    else
      client.say(text: "@#{reddituser}, you are already invited to this thread, check your inbox") # Can we pull their Slack ID here instead?
      puts "User is already a contributor of the thread"
    end
  end

  command 'add' do |client, data, msg| # livebot add <slug> <user> <perms>
    puts "\nGot an add command."
    userid = data["user"] # User ID of command sender
    if Permissions.user_check(userid) == true # If the list of admins (whitelist) includes the user who sent the command
      msg = msg.to_s.match(/.* (.*?) (.*) (.*)/)
      slug = msg[1]
      redditUser = msg[2]
      permissions = msg[3]
      puts "Thread: #{slug}"
      puts "User: #{redditUser}"
      accesstoken = Permissions.refreshtoken(refreshtoken)
      sleep 3
      Permissions.invite_user(accesstoken, redditUser, slug, permissions)
    else
      client.say(text: "You don't have the permissions to do that!", channel: data.channel)
      puts "User didn't have permissions."
    end
  end

  command 'lead' do |client, data, msg| # livebot lead <slug> <user>
    puts "\nGot a lead command."
    userid = data["user"] # User ID of command sender
    if Permissions.user_check(userid) == true # If the list of admins (whitelist) includes the user who sent the command
      msg = msg.to_s.match(/.* (.*?) (.*)/)
      slug = msg[1]
      redditUser = msg[2]
      puts "Thread: #{slug}"
      puts "User: #{redditUser}"
      accesstoken = Permissions.refreshtoken(refreshtoken)
      sleep 3
      Permissions.lead_user(accesstoken, redditUser, slug)
    else
      client.say(text: "You don't have the permissions to do that!", channel: data.channel)
      puts "User didn't have permissions."
    end
  end
end

Perms.run
