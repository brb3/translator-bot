#!/usr/bin/env ruby
require 'mastodon'
require 'curb'

class String
  # shamelessly stolen from the intertubes
  # Does a pretty decent job of stripping out tags from the incoming toots,
  # and also strips out the XML from Azure's Translation API.
  def strip_tags
    self.gsub(%r{</?[^>]+?>}, '')
  end

  # Dat sweet-sweet Unicode regex checking
  def japanese?
    !!(self =~ /\p{Katakana}|\p{Hiragana}/)
  end
end

# Gets an access totken for Azure
def get_token(azure_key)
  token_url = "https://api.cognitive.microsoft.com/sts/v1.0/issueToken"
  response = Curl.post(token_url) do |response|
    response.headers['Ocp-Apim-Subscription-key'] = azure_key
  end

  return response.body_str
end

# Connects to Azure and translate the toot's content
def translate_toot(toot, token)
  toot_content = toot.content.strip_tags
  translation_url = 
    "http://api.microsofttranslator.com/v2/Http.svc/Translate?" +
    "text=" + toot_content + "&to=en&from=ja"

  begin
    response = Curl.get(translation_url) do |response|
      response.headers['Authorization'] = "Bearer " + token
    end
  rescue
    return false
  end

  if response.status != "200 OK"
    return false
  end

  return response.body_str.strip_tags
end

# Does the work of establishing the connection to Mastodon
def connect_to_mastodon(token)
  Mastodon::REST::Client.new(
    base_url: 'https://mastodon.cloud', bearer_token: token
  )
end

# Get access token from secret.json
secret_file = File.open('secret.json', 'r')
json = secret_file.read
secret_file.close
secret_json = JSON.parse(json)

# Get access token for Azure
azure_token = get_token(secret_json['translator_token'])

# Connect to Mastodon
mastodon = connect_to_mastodon(secret_json['access_token'])

most_recent_id = nil
while true
  # grab the most recent 25 toots, or all the toots since our last set
  if most_recent_id.nil?
    toots = mastodon.public_timeline(limit: 25)
  else
    toots = mastodon.public_timeline(since_id: most_recent_id)
  end

  # If our list of toots is empty, wait 10 seconds, reconnect and make
  # another call to the API
  if toots.first.nil?
    sleep 10

    # I'm reconnecting here, because it tends to get hung if I don't. This
    # probably isn't necessary, I'm most likely doing something else wrong
    # somewhere
    mastodon = connect_to_mastodon(secret_json['access_token'])
    next
  else
    # keep track of our most recent toot
    most_recent_id = toots.first.id
  end

  # Find all of the Japanese toots and translate them
  japanese_toots = []
  toots.each do |toot|
    toot_content = toot.content.strip_tags
    if toot_content.japanese?
      translated = translate_toot(
        toot, azure_token
      )
      if translated
        japanese_toots << [toot, translated]
      end
    end
  end

  # Toot out the translations
  japanese_toots.each do |toot|
    begin
      translated_toot = "English Translation:\n" + toot[1]
      # Make sure we don't go over the maximum toot length
      if translated_toot.length <= 490
        mastodon.create_status(
          translated_toot,
          toot[0].id
        )
        puts "Tooted @ " + toot[0].account.acct
      end
    rescue
      puts "Failed tooting"
    end
  end
end
