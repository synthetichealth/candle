module Candle
  class Config
    CONTENT_TYPE = {'Content-Type'=>'application/fhir+json;charset=utf-8'}

    # Load the client_ids and settings from a configuration file
    CONFIGURATION = YAML.load(File.open(File.join(File.dirname(File.absolute_path(__FILE__)),'..','config.yml'),'r:UTF-8',&:read))

    # Load some static FHIR resources
    CAPABILITY_STATEMENT = File.open(File.join(File.dirname(File.absolute_path(__FILE__)),'resources','capabilitystatement.json'),'r:UTF-8',&:read)

    def self.dbconnect
      PG.connect :dbname => CONFIGURATION['database']['name'], :user => CONFIGURATION['database']['user']
    end
  end
end
