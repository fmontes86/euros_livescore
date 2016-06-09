require 'sinatra'
require 'json'
require 'rest-client'
require 'easy_translate'
require 'active_support/all'

set :fixtures, File.read('./data/fixtures.json')
set :matches_grouped_by_dates, proc { JSON.parse(settings.fixtures)["fixtures"].group_by{ |u| api_football_date_readable(u["date"]).strftime("%F") } }
set :today, %w(what what's is today? score score? scores play playing today)
set :tomorrow, %w(tomorrow tomorrow? play playing who whos is)
set :week, %w(who who's is week play playing next week?)
set :dates, %w(playing matches for at)

get '/' do
  'Hello world!'
end

get '/test.json' do
  response = RestClient.get 'http://api.football-data.org/v1/soccerseasons/424'
end

post "/ask" do
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
  # In the Google Developer Console credentials section: API Key > Server Key 
  # EasyTranslate.api_key = ENV["GOOGLE_API_KEY"]
  EasyTranslate.api_key = ENV["GOOGLE_API_KEY"]
  splat = translate(params[:text])
  text = if splat[:translate]
            EasyTranslate.translate(params[:text], from: splat[:from], to: splat[:to])
          else
            params[:text]
          end

  # if slack_date_readable(params[:timestamp]).strftime("%F") == "2016-06-10"
    text_analyzer(params[:user_id], text.downcase)
  # else
  #   post_to_channel("<@#{params[:user_id]}> There are no games for today! The Euro's start at 2016-06-10")
  # end
end

def post_to_channel(text, options={})
  RestClient.post('https://slack.com/api/chat.postMessage',
                  :token => ENV["SLACK_API_TOKEN"],
                  :channel => ENV["CHANNEL_ID"],
                  :as_user => true,
                  :text => text,
                  :attachments => options[:attachments])
end

def slack_date_readable(timestamp)
  Time.at(timestamp.to_i)
end

def api_football_date_readable(datetime)
  # The date would be giving as string and UTC (2016-06-10T19:00:00Z)
  timestamp = DateTime.rfc3339(datetime).to_time.to_i
  slack_date_readable(timestamp)
end

def text_analyzer(user_id, text)
  array_words = text.split(" ")

  if (array_words & settings.today).count > 1
    # today = Time.now.strftime("%F")
    date = "2016-06-10"
    text = "<@#{user_id}> This's the scores I've got so far for today:"
    attachments = { :attachments => format_attachments(find_match_by(date)).to_json }
  elsif (array_words & settings.tomorrow).count > 1
    # tomorrow = Time.now + 1.day
    date = "2016-06-11"
    text = "<@#{user_id}> This's the matches I've got for tomorrow:"
    attachments = { :attachments => format_attachments(find_match_by(date)).to_json }
  elsif (array_words & settings.week).count > 1
    date = (Time.now + 7.day).strftime("%F")
    text = "<@#{user_id}> This's the matches I've got for next week:"
    attachments = { :attachments => format_attachments(find_match_by(date)).to_json }
  elsif (array_words & settings.dates).count > 1
    date = array_words.join(" ")[/(\d{1,2}\-\d{1,2})/]
    real_date = "2016-"+date
    if real_date > "2016-07-10" || real_date < "2016-06-10"
      text = "Sorry, but I couldn't find something related to that date. Remember that I can only search by this format 'MM-DD'. Thanks! :happy_gf:"
      attachments = {}
    else
      text = "<@#{user_id}> This's the matches I've got for #{date}:"
      attachments = { :attachments => format_attachments(find_match_by(real_date)).to_json }
    end
  else
    text = "<@#{user_id}> Sorry I don't have enough information to show for now :sad_eder: I'm doing my best!"
    attachments = {}
  end
  post_to_channel(text, attachments)
end

def format_attachments(content)
  matches = []
  unless content.empty?
    content.each_with_index do |match, index|
      res = JSON.parse(RestClient.get(match["_links"]["self"]["href"]))
      matches.push(
        {
          :text => "Match #{index + 1} - #{api_football_date_readable(match['date']).strftime('%b, %d at %H:%M %z')}",
          :mrkdwn_in => ["text", "pretext", "fields"],
          :fields => [
            {
              :title => res["fixture"]['homeTeamName'],
              :value => res["fixture"]["result"]["goalsHomeTeam"] || 0,
              :short => true
            },
            {
              :title => res["fixture"]['awayTeamName'],
              :value => res["fixture"]["result"]["goalsAwayTeam"] || 0,
              :short => true
            }
          ],
          :color => "#F35A00"
        }
      )
    end
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
  else
    []
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
