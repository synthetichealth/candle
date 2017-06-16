# OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

require 'yaml'
require 'logger'

require 'bundler/setup'
Bundler.require(:default)

Dir.glob(File.join(File.dirname(File.absolute_path(__FILE__)),'lib','*.rb')).each do |file|
  require file
end

DB = Sequel.connect(adapter: 'postgres', :host => Candle::Config::CONFIGURATION['database']['host'],
  :database => Candle::Config::CONFIGURATION['database']['name'],
  :user => Candle::Config::CONFIGURATION['database']['user'],
  :password => Candle::Config::CONFIGURATION['database']['password'])

DB.loggers << Logger.new($stdout)

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
  # reject XML requests
  if request.content_type && !Candle::Helpers.valid_content_type(request.content_type)
    # We only support JSON
    error = Candle::Helpers.reject_content_type(content_type)
    [422, Candle::Config::CONTENT_TYPE, error.to_json]
  else
    # Return Static CapabilityStatement
    [200, Candle::Config::CONTENT_TYPE, Candle::Config::CAPABILITY_STATEMENT]
  end
end

# Any methods or paths not supported...
error Sinatra::NotFound do
  error = FHIR::OperationOutcome.new
  error.issue << FHIR::OperationOutcome::Issue.new
  error.issue.last.severity = 'error'
  error.issue.last.code = 'not-supported'
  error.issue.last.diagnostics = "The interaction `#{request.request_method} #{request.url}` is not supported."
  [404, Candle::Config::CONTENT_TYPE, error.to_json]
end

# FHIR Patient READ
get '/fhir/Patient/:id' do |id|
  Candle::Patient.read(id)
end

# FHIR Patient SEARCH
get '/fhir/Patient/?' do
  Candle::Patient.search(request, params)
end

# FHIR Patient CREATE
post '/fhir/Patient/?' do
  Candle::Patient.create(request.body.read, request.content_type)
end

# FHIR Observation READ
get '/fhir/Observation/:id' do |id|
  Candle::Observation.read(id)
end

# FHIR Observation SEARCH
get '/fhir/Observation/?' do
  Candle::Observation.search(request, params)
end

# FHIR Observation CREATE
post '/fhir/Observation/?' do
  Candle::Observation.create(request.body.read, nil, nil, request.content_type)
end
