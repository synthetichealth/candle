module Candle
  class Security
    # TODO White list parameters
    # TODO Check parameter datatypes
    # TODO Filter parameters on allowed values
    def self.sanitize(params)
      if params.is_a?(Hash)
        has = []
        downcase = {}
        params.each do |key, value|
          params[key] = sanitize(value)
          downcase[key.downcase] = params[key]
          if key.start_with?('_has')
            has << key.split(':')[1..-1]
            has.last << value
          end
        end
        params.merge!(downcase)
        params['_has'] = has unless has.empty?
      elsif params.is_a?(String)
        value = params.gsub("'","''")
        value = Integer(value) if integer?(value)
        value
      elsif params.is_a?(Numeric)
        params
      end
    end

    def self.integer?(value)
      true if Integer(value) rescue false
    end
  end
end
