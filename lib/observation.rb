module Candle
  class Observation

    def self.create(payload, patient_id, encounter_id, content_type = 'application/fhir+json')
      begin
        observation = FHIR.from_contents(payload)
        is_observation = observation.is_a?(FHIR::Observation)
        validate_errors = observation.validate
        bad_input = !validate_errors.empty?
      rescue => e
        puts 'Failed to parse Observation.'
        puts e
        parameters = nil
        validate_errors = [ 'Failed to parse Observation.' ]
        bad_input = true
      end
      if content_type && !content_type.start_with?('application/fhir+json')
        # We only support JSON
        error = FHIR::OperationOutcome.new
        error.issue << FHIR::OperationOutcome::Issue.new
        error.issue.last.severity = 'error'
        error.issue.last.code = 'not-supported'
        error.issue.last.diagnostics = "The content-type `#{content_type}` is not supported. This service only supports `application/fhir+json`."
        response_code = 422
        response_body = error.to_json
      elsif bad_input
        # We only support valid Observation resources
        error = FHIR::OperationOutcome.new
        error.issue << FHIR::OperationOutcome::Issue.new
        error.issue.last.severity = 'error'
        error.issue.last.code = 'required'
        error.issue.last.diagnostics = 'This operation requires a valid FHIR Observation Resource.'
        validate_errors.each do |error_message|
          error.issue << FHIR::OperationOutcome::Issue.new
          error.issue.last.severity = 'error'
          error.issue.last.code = 'required'
          error.issue.last.diagnostics = error_message
        end
        response_code = 422
        response_body = error.to_json
      else
        # Add the observation to the database
        begin
          con = Candle::Config.dbconnect
          con.transaction do |con|
            patient = patient_id || (Candle::Helpers.extract_id(observation.subject.reference, 'Patient') rescue 'null')
            patient = 'null' unless patient
            encounter = encounter_id || (Candle::Helpers.extract_id(observation.context.reference, 'Encounter') rescue 'null')
            encounter = 'null' unless encounter
            code = observation.code.coding.map{|coding| [coding.system, coding.code].compact.join(' ')}.compact.join(' ')
            components = observation.component.map{|component| component.code.coding.map{|coding| [coding.system, coding.code].compact.join(' ')}.compact.join(' ') }.compact.join(' ')
            code += " #{components}" if components
            code = Candle::Security.sanitize(code)
            observation.id = nil
            resource = Candle::Security.sanitize(observation.to_json)
            statement = "INSERT INTO observation(patient,encounter,code,resource) VALUES(#{patient},#{encounter},'#{code}','#{resource}') RETURNING id;"
            puts statement
            rs = con.exec(statement)
            observation.id = rs.getvalue(0, 0)
          end
          response_code = 201
          response_location = observation.id
          response_body = observation.to_json
        rescue PG::Error => e
          response_code = 400
          error = FHIR::OperationOutcome.new
          error.issue << FHIR::OperationOutcome::Issue.new
          error.issue.last.severity = 'error'
          error.issue.last.code = 'required'
          error.issue.last.diagnostics = e.message
          response_body = error.to_json
        ensure
          con.close if con
        end
      end
      # Return the results
      headers = Hash.new.merge(Candle::Config::CONTENT_TYPE)
      headers['location'] = response_location if response_location
      [response_code, headers, response_body]
    end

    def self.read(id)
      id = Candle::Security.sanitize(id)
      return [404, Candle::Config::CONTENT_TYPE, nil] unless id.is_a?(Numeric)
      begin
        con = Candle::Config.dbconnect
        observation = nil
        con.transaction do |con|
          query = "SELECT resource FROM observation WHERE id = #{id}"
          puts "QUERY: #{query}"
          rs = con.exec(query)
          if rs.ntuples > 0
            json = rs.getvalue(0, 0)
            observation = FHIR.from_contents(json)
          end
        end
        if observation
          response_code = 200
          observation.id = id
          response_body = observation.to_json
        else
          response_code = 404
          response_body = nil
        end
      rescue PG::Error => e
        response_code = 400
        error = FHIR::OperationOutcome.new
        error.issue << FHIR::OperationOutcome::Issue.new
        error.issue.last.severity = 'error'
        error.issue.last.code = 'required'
        error.issue.last.diagnostics = e.message
        response_body = error.to_json
      ensure
        con.close if con
      end
      [response_code, Candle::Config::CONTENT_TYPE, response_body]
    end

    def self.search(request, params)
      Candle::Security.sanitize(params)
      patient = params['patient']
      encounter = params['encounter']
      code = params['code']
      date = params['date']
      value = params['value-quantity']
      page_raw = params['page']
      page_given = !page_raw.nil?
      page = (page_raw.to_i rescue 0)
      page = 0 if page < 0
      params.delete('page')
      begin
        con = Candle::Config.dbconnect
        observation = nil
        query = 'SELECT id, resource FROM observation WHERE'
        query += " id > #{page}"
        count = 'SELECT count(*) FROM observation'
        unless params.empty?
          clauses = []
          clauses << " patient = #{patient}" if patient
          clauses << " encounter = #{encounter}" if encounter
          clauses << " code ILIKE '%#{code}%'" if code
          # clauses << " resource @> '{ \"gender\": \"#{gender}\" }'" if gender
          if date # TODO: handle effectPeriod.start
            if date.start_with?('eq')
              clauses << " to_date(resource ->> 'effectiveDateTime', 'YYYY-MM-DD') = '#{date[2..-1]}'"
            elsif date.start_with?('ge')
              clauses << " to_date(resource ->> 'effectiveDateTime', 'YYYY-MM-DD') >= '#{date[2..-1]}'"
            else
              # fastest
              # clauses << " resource @> '{ \"effectiveDateTime\": \"#{date}\" }'"
              clauses << " to_date(resource ->> 'effectiveDateTime', 'YYYY-MM-DD') = '#{date}'"
            end
          end
          if value
            operator = if value.start_with?('le')
              value = value[2..-1]
              '<='
            elsif value.start_with?('lt')
              value = value[2..-1]
              '<'
            elsif value.start_with?('ge')
              value = value[2..-1]
              '>='
            elsif value.start_with?('gt')
              value = value[2..-1]
              '>'
            else
              '='
            end
            clauses << " to_number(resource #>>'{valueQuantity,value}','9999D99') #{operator} #{value.to_f}"
          end
          query += ' AND' unless clauses.empty?
          query += clauses.join(' AND')
          count += ' WHERE' unless clauses.empty?
          count += clauses.join(' AND')
        end
        query += " ORDER BY id LIMIT #{Candle::Config::CONFIGURATION['page_size']}"
        puts "QUERY: #{query}"
        puts "COUNT: #{count}"
        bundle = FHIR::Bundle.new({'type'=>'searchset','total'=>0})
        page_total = 0
        start = Time.now
        con.transaction do |con|
          cs = con.exec(count)
          bundle.total = cs.getvalue(0, 0).to_i
          rs = con.exec(query)
          rs.each do |row|
            id = row['id']
            json = row['resource']
            resource = FHIR.from_contents(json)
            resource.id = id
            bundle.entry << Candle::Helpers.bundle_entry("#{request.base_url}/fhir/Observation/#{id}", resource)
          end
          page_total = rs.ntuples
          bundle.link << FHIR::Bundle::Link.new({'relation': 'self', 'url': request.url})
        end
        if bundle.total >= 0 || page_given
          begin
            start_page_from_index = bundle.entry.last.resource.id
            request_url = request.url
            if request.query_string.empty?
              request_url += "?page=#{start_page_from_index}"
            elsif !request.query_string.include?('page=')
              request_url += "&page=#{start_page_from_index}"
            else
              request_url.gsub!("page=#{page_raw}","page=#{start_page_from_index}")
            end
            bundle.link << FHIR::Bundle::Link.new({'relation': 'next', 'url': request_url}) if page_total > 0
          rescue
          end
        end
        finish = Time.now
        puts "Database query took #{finish - start} s."
        response_code = 200
        response_body = bundle.to_json
      rescue PG::Error => e
        response_code = 400
        error = FHIR::OperationOutcome.new
        error.issue << FHIR::OperationOutcome::Issue.new
        error.issue.last.severity = 'error'
        error.issue.last.code = 'required'
        error.issue.last.diagnostics = e.message
        response_body = error.to_json
      ensure
        con.close if con
      end
      [response_code, Candle::Config::CONTENT_TYPE, response_body]
    end

  end
end
