require 'bundler/setup'
Bundler.require(:default, :test)
require 'minitest/autorun'
require 'minitest/emoji'
require './lib/config'

DB = Sequel.connect(adapter: 'postgres', :host => Candle::Config::CONFIGURATION['database']['host'],
  :database => Candle::Config::CONFIGURATION['database']['name'],
  :user => Candle::Config::CONFIGURATION['database']['user'],
  :password => Candle::Config::CONFIGURATION['database']['password'])

require './lib/config'
require './lib/helpers'

class SequelTestCase < Minitest::Test
  def run(*args, &block)
    DB.transaction(:rollback=>:always, :auto_savepoint=>true){super}
  end
end
