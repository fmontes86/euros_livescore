require 'sinatra'
require 'json'
require 'rest-client'
require 'easy_translate'
require 'slack'
require 'slack-ruby-client'

Slack.configure do |config|
  config.token = "xoxb-48038287187-q3BAxodjkCsq51AUR9CpenPY"
end

client = Slack::RealTime::Client.new

client.on :hello do
  p 'Successfully connected.'
end

client.on :message do |data|
  # respond to messages
  p data
end

set :fixtures, File.read('./data/fixtures.json')
set :matches_grouped_by_dates, proc { JSON.parse(settings.fixtures)["fixtures"].group_by{ |u| api_football_date_readable(u["date"]) } }

get '/' do
  'Hello world!'
end

get '/test.json' do
  response = RestClient.get 'http://api.football-data.org/v1/soccerseasons/424'
end

post '/auth' do
  p "auth"
  p params
end

post "/ask" do
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
  # In the Google Developer Console credentials section: API Key > Server Key 
  # EasyTranslate.api_key = ENV['GOOGLE_API_KEY']
  EasyTranslate.api_key = "AIzaSyAtYhDY2p1NHbSlaCLUdyzvrZDbLuzCZTw"
  splat = translate(params[:text])
  text = EasyTranslate.translate(params[:text], from: splat[:from], to: splat[:to])

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
  # text_analyzer(text.downcase)
end

def slack_date_readable(timestamp)
  Time.at(timestamp).utc
end

def api_football_date_readable(datetime)
  # The date would be giving as string and UTC (2016-06-10T19:00:00Z)
  timestamp = DateTime.rfc3339(datetime).to_time.to_i
  slack_date_readable(timestamp).strftime("%F")
end

def text_analyzer(text)
  array_words = text.split(" ")
  fixtures_json = JSON.parse(settings.fixtures)
  if array_words.include?("today?") && array_words.include?("play")
    # today = Time.now.strftime("%F")
    today = "2016-06-10"
    find_match_by(today)
  end
  # p fixtures_json["fixtures"][0]
  # Have to define what could I analize here
  # 1.- Matches of the day
  # 2.- Goals
  # 3.- Futurres matches - Dates
  # 4.- 
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
    settings.matches_grouped_by_dates.values_at(date).flatten.each do |match|
      p match["homeTeamName"]
      p match["awayTeamName"]
      # 
      # Find the way to post into slack!!!
      # 
    end
  end
  # settings.matches_grouped_by_dates.each do |date, data|
  #   p date
  #   data.each do |match|
  #     p match["homeTeamName"]
  #     p match["awayTeamName"]
  #   end
  # end
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

  { from: detected_language, to: translate_to }
end
