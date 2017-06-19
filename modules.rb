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
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end

    responseparsed = JSON.parse(response.body) # List of contributors
    contributors = []
    responseparsed.each do |row|
      row["data"]["children"].each do |child|
        contributors << child['name']
      end
    end

    permissions = "+all" # Full perms

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
    user_status = {}
    whitelist = YAML.load_file('whitelist.yaml') # Load up our whitelist
    admins = whitelist["admins"] # Load in our admins array
    if admins.include?(userid) # If the list of admins includes our user
      user_status[:is_admin] = true
    else
      user_status[:is_admin] = false
    end
    contributors = whitelist["contributors"] # Contributors array for join command
    if contributors.include?(userid) # If the list of contribs includes our user
      user_status[:is_contributor] = true # Already invited, #{redditUser}, go check inbox and accept invite
    else
      user_status[:is_contributor] = false # Send contributor invite
    end
    puts user_status
    return user_status
  end
  def self.yaml_contributor(userid, slug)
    # Check if the threads.yaml has our thread. If it does, check if the thread contains our contributor.
    # Return true if it does, and false if it doesn't.
    threads = YAML.load_file('threads.yaml')
    if threads.any? {|key| key.include? slug} == true # Does threads.yaml have our thread? If it does:
      puts "Thread is already in threads.yaml"
      if threads[slug].include? userid == true # Does the thread have our contributor? If it does:
        return true
      else # If the thread doesn't include our contributor
        return false
      end
    end
  end
  def self.add_contributor_to_yaml(userid, slug) # Add Slack user ID to threads.yaml, under an individual thread slug array. If it doesn't exist, create one.
    # Check if the threads.yaml already has our thread. If it doesn't, create one and go ahead with the ID check
    # If it does have one, check the slug for our ID, if it exists, done
    # If the slug doesn't have our ID, add it
    threads = YAML.load_file('threads.yaml')
    if threads == false # If threads.yaml is empty
      data = {slug => [userid]}
      File.open("threads.yaml", "w") {|f| f.write(data.to_yaml)} # Write to threads, adding our contributor to the thread
      return
    end
    if threads.any? {|key| key.include? slug} == true # Does threads.yaml have our thread? If it does:
      puts "Thread is already in threads.yaml"
      if threads[slug].include? userid == true # Does the thread have our contributor? If it does:
        puts "Contributor is already in #{slug} in threads.yaml"
      else # If the thread doesn't have our user ID
        threads[slug] = [userid] # Write to threads, adding our contributor to the thread
        puts "Added contributor (#{userid}) to #{slug}"
      end
    else # If thread doesn't exist in threads.yaml
      data = {slug => []}
      File.open("threads.yaml", "w") {|f| f.write(data.to_yaml)}
    end
  end

  def self.create_thread(title, description, *resources)
    # Create thread with title, description and (optionally) resources. The third arg is an array, but needs to be a string (for Reddit API).
    # description must be in "raw markdown text"
    # resources must be in "raw markdown text"
    # title must be a string no longer than 120 characters
    
    if resources == [] # If resources isn't given as an arg (blank)
      resources = "" # Resources will be nil for Reddit request
    end

    uri = URI.parse("https://www.oauth.reddit.com/api/live/create")

    request = Net::HTTP::Get.new(uri.path, {'User-Agent' => 'desktop:com.VolunteerLiveTeam.livebot:v1.0.0 (by /u/everyboysfantasy)'})

    request.add_field("Authorization", "bearer #{accesstoken}") # Uses our access token for OAuth2
    request.add_field("Content-Type", "application/json") # JSON needed for POST requests, not for GET requests
    
    request.form_data = {
      "api_type" => "json",
      "description" => description,
      "nsfw" => false,
      resources => resources,
      title => title,
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
end # Module end 
