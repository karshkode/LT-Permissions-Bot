require 'slack-ruby-bot'
require 'net/http'
require 'uri'
require 'json'
require 'openssl'
require 'yaml'

$config = YAML.load_file('config.yaml') # Load for all secret keys and tokens

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

module Permissions

  def self.refreshtoken(refreshtoken)
    # Refreshes the token, needs to be called every hour, given the refreshtoken OR every time the perms bot command is called
    uri = URI.parse("https://www.reddit.com/api/v1/access_token")
    request = Net::HTTP::Post.new(uri.path, {'User-Agent' => 'desktop:com.VolunteerLiveTeam.livebot:v1.0.0 (by /u/everyboysfantasy)'})
    request.basic_auth($config["client_id"], $config["client_secret"]) # client_id, client_secret
    request.set_form_data(
      "grant_type" => "refresh_token",
      "refresh_token" => refreshtoken,
      "redirect_uri" => "http://localhost",
    )

    tries = 0
    begin
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
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

    puts "#{response} in #{__method__}"
    json = JSON.parse(response.body)
    access_token = json["access_token"]
    return access_token
  end


  def self.invite_user(accesstoken, redditUser, slug, permissions)
    # Invites a user to a specified live thread, and sets specific permissions
    uri = URI.parse("https://www.oauth.reddit.com/api/live/#{slug}/invite_contributor/")

    request = Net::HTTP::Post.new(uri.path, {'User-Agent' => 'desktop:com.VolunteerLiveTeam.livebot:v1.0.0 (by /u/everyboysfantasy)'})

    request.add_field("Authorization", "bearer #{accesstoken}") # Uses our access token for OAuth2
    request.add_field("Content-Type", "application/json")

    request.form_data = {
      "api_type" => "json",
      "name" => redditUser,
      "permissions" => permissions,
      "type" => "liveupdate_contributor_invite"
    }

    tries = 0
    begin
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
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

    puts "#{response} in #{__method__}" #remove .body once debugged
  end

  def self.lead_user(accesstoken, redditUser, slug)
    # Check if user is already a contributor, if so, update perms, if not, invite with full perms

    uri = URI.parse("https://www.oauth.reddit.com/api/live/#{slug}/contributors/")

    request = Net::HTTP::Get.new(uri.path, {'User-Agent' => 'desktop:com.VolunteerLiveTeam.livebot:v1.0.0 (by /u/everyboysfantasy)'})

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

  def self.update_perms(accesstoken, redditUser, slug, permissions)
    # Updates the permissions for a contributor
    uri = URI.parse("https://www.oauth.reddit.com/api/live/#{slug}/set_contributor_permissions")

    request = Net::HTTP::Post.new(uri.path, {'User-Agent' => 'desktop:com.VolunteerLiveTeam.livebot:v1.0.0 (by /u/everyboysfantasy)'})

    request.add_field("Authorization", "bearer #{accesstoken}") # Uses our access token for OAuth2
    request.add_field("Content-Type", "application/json")

    request.form_data = {
      "api_type" => "json",
      "name" => redditUser,
      "permissions" => permissions,
      "type" => "liveupdate_contributor_invite"
    }

    tries = 0
    begin
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
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

    puts "#{response} in #{__method__}"
  end
  
  def self.user_check(userid)

    whitelist = YAML.load_file('whitelist.yaml') # Load up our whitelist
    admins = whitelist["admins"] # Load in our admins array
    if admins.include?(userid) # If the list of admins includes our user
      return true
    else
      return false
    end

  end

end
