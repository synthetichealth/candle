require 'bundler/setup'
Bundler.require(:default, :test)
require 'minitest/autorun'
require 'minitest/emoji'

DB = Sequel.connect(adapter: 'postgres', host: 'localhost', database: 'candle')

require './lib/config'
require './lib/helpers'

class SequelTestCase < Minitest::Test
  def run(*args, &block)
    DB.transaction(:rollback=>:always, :auto_savepoint=>true){super}
  end
end
