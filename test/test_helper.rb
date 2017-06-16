require 'bundler/setup'
Bundler.require(:default, :test)

DB = Sequel.connect(adapter: 'postgres', host: 'localhost', database: 'candle')

require './lib/config'

class SequelTestCase < Minitest::Test
  def run(*args, &block)
    DB.transaction(:rollback=>:always, :auto_savepoint=>true){super}
  end
end
