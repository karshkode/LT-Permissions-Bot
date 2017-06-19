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

  # Help for our Perms part of bot

  help do
    title 'Live Bot'
    desc 'This bot allows users to join live threads from Slack, and set lead users for that thread.'
    
    command 'join' do
      desc 'This command allows any user to join a live thread with no permissions.'
    end
    command 'add' do
      desc 'Only available to trusted contributors (see Tyree for more details), this command allows users to add themselves to live threads with certain permissions.'
    end
    command 'lead' do
      desc 'Only available to admins, this command allows users to designate a lead for a certain live thread, giving them full permissions on that thread.'
    end
  end

refreshtoken = $config["refresh_token"]

command 'join' do |client, data, msg|
  # livebot join <slug> <user>
  # Everybody can use it
  puts "\nGot a join command."
  userid = data["user"] # User ID of command sender
  msg = msg.to_s.match(/.* (.*?) (.*)/)
  slug = msg[1]
  redditUser = msg[2]
  puts "Thread: #{slug}"
  puts "User: #{redditUser}"
  if Permissions.yaml_contributor == false # If the user is not on the contributors list for our thread
    accesstoken = Permissions.refreshtoken(refreshtoken)
    sleep 3 # implement as an error exception for 429 so we only sleep when it fails
    Permissions.invite_user(accesstoken, redditUser, slug, "-all")
    Permissions.add_contributor_to_yaml(userid, slug) # Add user as contributor of our thread to threads.yaml
  else
    client.say(text: "#{redditUser} is already invited to this thread, check your inbox", channel: data.channel) # Can we pull their Slack ID here instead?
    puts "User is already a contributor of the thread"
  end
end

command 'add' do |client, data, msg|
  # livebot add <slug> <user> <perms>
  # Only admins can use it (at the moment)
  puts "\nGot an add command."
  userid = data["user"] # User ID of command sender
  msg = msg.to_s.match(/.* (.*?) (.*) (.*)/)
  slug = msg[1]
  redditUser = msg[2]
  permissions = msg[3]
  puts "Thread: #{slug}"
  puts "User: #{redditUser}"
  if Permissions.user_check(userid)[:is_contributor] == true # If the list of contributors (whitelist) includes the user who sent the command
    accesstoken = Permissions.refreshtoken(refreshtoken)
    sleep 3
    Permissions.invite_user(accesstoken, redditUser, slug, permissions)
    Permissions.add_contributor_to_yaml(userid, slug) # Add user as contributor of our thread to threads.yaml
  else
    client.say(text: "You don't have the permissions to do that!", channel: data.channel)
    puts "User didn't have permissions."
  end
end

command 'lead' do |client, data, msg|
  # livebot lead <slug> <user>
  # Only admins can use it (at the moment)
  puts "\nGot a lead command."
  userid = data["user"] # User ID of command sender
  msg = msg.to_s.match(/.* (.*?) (.*)/)
  slug = msg[1]
  redditUser = msg[2]
  puts "Thread: #{slug}"
  puts "User: #{redditUser}"
  if Permissions.user_check(userid)[:is_admin] == true # If the list of admins (whitelist) includes the user who sent the command
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
