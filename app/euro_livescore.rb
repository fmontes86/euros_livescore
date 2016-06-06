require 'sinatra'
require 'json'
require 'rest-client'

get '/' do
  'Hello world!'
end

get '/test.json' do
  response = RestClient.get 'http://api.football-data.org/v1/soccerseasons/424'
end

get "/scores" do
  p params
end

post "/ask" do
  p params
end

