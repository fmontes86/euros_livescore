require 'sinatra'
require 'json'
require 'rest-client'
require 'easy_translate'
require 'active_support/all'

set :fixtures, File.read('./data/fixtures.json')
set :matches_grouped_by_dates, proc { JSON.parse(settings.fixtures)["fixtures"].group_by{ |u| api_football_date_readable(u["date"]).strftime("%F") } }

get '/' do
  'Hello world!'
end

get '/test.json' do
  response = RestClient.get 'http://api.football-data.org/v1/soccerseasons/424'
end

post "/ask" do
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
  # In the Google Developer Console credentials section: API Key > Server Key 
  EasyTranslate.api_key = ENV["GOOGLE_API_KEY"]
  splat = translate(params[:text])
  text = if splat[:translate]
            EasyTranslate.translate(params[:text], from: splat[:from], to: splat[:to])
          else
            params[:text]
          end

  # {
  #   "token"=>"dMjCtD6mmN5SbGxUKOGKlFKO", 
  #   "team_id"=>"T027P7MLU", 
  #   "team_domain"=>"ableco", 
  #   "service_id"=>"48122202561", 
  #   "channel_id"=>"C1E3RFTJM", 
  #   "channel_name"=>"euros_championship_sc", 
  #   "timestamp"=>"1465251469.000005", 
  #   "user_id"=>"U0E595ECA", 
  #   "user_name"=>"felix", 
  #   "text"=>"hola vale!"
  # }

  text_analyzer(params[:user_id], text.downcase)
end

def post_to_channel(text, options={})
  RestClient.post('https://slack.com/api/chat.postMessage',
                        :token => ENV["SLACK_API_TOKEN"], 
                        :channel => ENV["CHANNEL_ID"], 
                        :as_user => true, 
                        :text => text, 
                        :attachments => options[:attachments]
                      )
end

def slack_date_readable(timestamp)
  Time.at(timestamp)
end

def api_football_date_readable(datetime)
  # The date would be giving as string and UTC (2016-06-10T19:00:00Z)
  timestamp = DateTime.rfc3339(datetime).to_time.to_i
  slack_date_readable(timestamp)
end

def text_analyzer(user_id, text)
  array_words = text.split(" ")
  fixtures_json = JSON.parse(settings.fixtures)
  if array_words.include?("today?") && array_words.include?("playing") || array_words.include?("what") && array_words.include?("scores")
    # today = Time.now.strftime("%F")
    # tomorrow = Time.now + 1.day
    today = "2016-06-11"
    post_to_channel("<@#{user_id}> This's the scores I've got so far...", { :attachments => format_attachments(find_match_by(today)).to_json })
  elsif array_words.include?("tomorrow?") && array_words.include?("play")
    # tomorrow = Time.now + 1.day
    today = "2016-06-12"
    post_to_channel("<@#{user_id}> This's the scores I've got so far...", { :attachments => format_attachments(find_match_by(today)).to_json })
  elsif array_words.include?("week") && array_words.include?("from") && array_words.include?("now?")  
    today = (Time.now + 7.day).strftime("%F")
    post_to_channel("<@#{user_id}> This's the scores I've got so far...", { :attachments => format_attachments(find_match_by(today)).to_json })
  else
    post_to_channel("<@#{user_id}> Sorry I don't reconigized what are you trying to said :sad_eder: I'm doing my best!")
  end
end

def format_attachments(content)
  matches = []
  content.each_with_index do |match, index|
    matches.push(
      {
        :text => "Match #{index + 1} - #{api_football_date_readable(match['date']).strftime('%b, %d at %H:%M %z')}",
        :mrkdwn_in => ["text", "pretext", "fields"],
        :fields => [
          {
            :title => match['homeTeamName'] || 0,
            :value => match['goalsHomeTeam'] || 0,
            :short => true
          },
          {
            :title => match['awayTeamName'] || 0,
            :value => match['goalsAwayTeam'] || 0,
            :short => true
          }
        ],
        :color => "#F35A00"
      }
    )
  end
  matches
end

def compare_date(slack_date, api_date)
  if slack_date.strftime("%F") > api_date.strftime("%F")
    # stuff when its gather
  elsif slack_date.strftime("%F") < api_date.strftime("%F")
    # stuff when its lower
  else
    # stuff when its equal
  end
end

def find_match_by(date)
  if settings.matches_grouped_by_dates.has_key?(date)
    settings.matches_grouped_by_dates.values_at(date).flatten
  end
end

def translate phrase
  results = EasyTranslate.detect(phrase, confidence: true)
  detected_language = results[:language]
  #logger.info results.inspect

  translate_to = if results[:confidence] >= 0.02
    detected_language.eql?('en') ? 'es' : 'en'
  elsif detected_language.eql?('en')
    'es'
  else
    detected_language = 'es'
    'en'
  end

  { from: detected_language, to: translate_to, translate: detected_language.eql?("es") }
end
