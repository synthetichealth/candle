# OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

require 'yaml'
require 'sinatra'
require 'sinatra/cross_origin'
require 'fhir_models'
require 'pg'

Dir.glob(File.join(File.dirname(File.absolute_path(__FILE__)),'lib','*.rb')).each do |file|
  require file
end

enable :cross_origin
register Sinatra::CrossOrigin
enable :sessions
set :session_secret, SecureRandom.uuid

# OPTIONS for CORS preflight requests
options '*' do
  response.headers['Allow'] = 'HEAD,GET,PUT,POST,DELETE,OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept'
  200
end

# Root: redirect to /index
get '/' do
  redirect to('/fhir/metadata')
end

get '/fhir' do
  redirect to('/fhir/metadata')
end

# FHIR CapabilityStatement
get '/fhir/metadata' do
  # Return Static CapabilityStatement
  [200, Candle::Config::CONTENT_TYPE, Candle::Config::CAPABILITY_STATEMENT]
end

# FHIR Patient READ
get '/fhir/Patient/:id' do |id|
  Candle::Patient.read(id)
end

# FHIR Patient SEARCH
get '/fhir/Patient' do
  Candle::Patient.search(request, params)
end

# FHIR Patient CREATE
post '/fhir/Patient' do
  Candle::Patient.create(request.body.read, request.content_type)
end

# FHIR Observation READ
get '/fhir/Observation/:id' do |id|
  Candle::Observation.read(id)
end

# FHIR Observation SEARCH
get '/fhir/Observation' do
  Candle::Observation.search(request, params)
end

# FHIR Observation CREATE
post '/fhir/Observation' do
  Candle::Observation.create(request.body.read, nil, nil, request.content_type)
end
