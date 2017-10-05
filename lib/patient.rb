module Candle
  class Patient
    RACE_EXT = 'http://hl7.org/fhir/StructureDefinition/us-core-race'.freeze
    ETHNICITY_EXT = 'http://hl7.org/fhir/StructureDefinition/us-core-ethnicity'.freeze

    def self.create(payload, content_type = 'application/fhir+json')
      begin
        patient = FHIR.from_contents(payload)
        is_patient = patient.is_a?(FHIR::Patient)
        validate_errors = patient.validate
        bad_input = !validate_errors.empty?
      rescue => e
        puts 'Failed to parse Patient.'
        puts e
        parameters = nil
        validate_errors = [ 'Failed to parse Patient.' ]
        bad_input = true
      end
      if !Candle::Helpers.valid_content_type(content_type)
        # We only support JSON
        error = Candle::Helpers.reject_content_type(content_type)
        response_code = 422
        response_body = error.to_json
      elsif bad_input
        # We only support valid Patient resources
        error = FHIR::OperationOutcome.new
        error.issue << FHIR::OperationOutcome::Issue.new
        error.issue.last.severity = 'error'
        error.issue.last.code = 'required'
        error.issue.last.diagnostics = 'This operation requires a valid FHIR Patient Resource.'
        validate_errors.each do |error_message|
          error.issue << FHIR::OperationOutcome::Issue.new
          error.issue.last.severity = 'error'
          error.issue.last.code = 'required'
          error.issue.last.diagnostics = error_message
        end
        response_code = 422
        response_body = error.to_json
      else
        # Add the patient to the database
        begin
          con = Candle::Config.dbconnect
          con.transaction do |con|
            name = patient.name.map{|name| [name.text, name.family, name.given].flatten.compact.join(' ')}.compact.join(' ')
            name = Candle::Security.sanitize(name, 64)
            race = patient.extension.find{|x| x.url == RACE_EXT}.valueCodeableConcept.coding.first.code rescue 'null'
            race = Candle::Security.sanitize(race, 6)
            ethnicity = patient.extension.find{|x| x.url == ETHNICITY_EXT}.valueCodeableConcept.coding.first.code rescue 'null'
            ethnicity = Candle::Security.sanitize(ethnicity, 6)
            patient.id = nil
            resource = Candle::Security.sanitize(patient.to_json)
            statement = "INSERT INTO patient(name,resource,race,ethnicity) VALUES('#{name}','#{resource}','#{race}','#{ethnicity}') RETURNING id;"
            # puts statement
            rs = con.exec(statement)
            patient.id = rs.getvalue(0, 0)
          end
          response_code = 201
          response_location = "Patient/#{patient.id}"
          response_body = patient.to_json
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
        patient = nil
        con.transaction do |con|
          query = "SELECT resource FROM patient WHERE id = #{id}"
          puts "QUERY: #{query}"
          rs = con.exec(query)
          if rs.ntuples > 0
            json = rs.getvalue(0, 0)
            patient = FHIR.from_contents(json)
          end
        end
        if patient
          response_code = 200
          patient.id = id
          response_body = patient.to_json
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
      name = params['name']
      gender = params['gender']
      birthDate = params['birthdate']
      race = params['race']
      ethnicity = params['ethnicity']
      city = params['address-city']
      has = params['_has']
      page_raw = params['page']
      page_given = !page_raw.nil?
      page = (page_raw.to_i rescue 0)
      page = 0 if page < 0
      params.delete('page')
      begin
        con = Candle::Config.dbconnect
        patient = nil
        selectq = 'patient.id, patient.resource'
        selectq = 'distinct(patient.id), patient.resource' if has
        fromq = ['patient']
        clauses = []
        if has
          has.each do |join|
            fromq << join[0].downcase
            clauses << "#{join[0].downcase}.#{join[1]} = patient.id"
          end
        end
        pageq = "patient.id > #{page}"
        countq = 'count(*)'
        countq = 'count(distinct(patient.id))' if has
        unless params.empty?
          clauses << "patient.race = '#{race}'" if race
          clauses << "patient.ethnicity = '#{ethnicity}'" if ethnicity
          clauses << "patient.name ILIKE '%#{name}%'" if name
          clauses << "patient.resource @> '{ \"gender\": \"#{gender}\" }'" if gender
          if birthDate
            if birthDate.start_with?('eq')
              clauses << "to_date(patient.resource ->> 'birthDate', 'YYYY-MM-DD') = '#{birthDate[2..-1]}'"
            elsif birthDate.start_with?('ge')
              clauses << "to_date(patient.resource ->> 'birthDate', 'YYYY-MM-DD') >= '#{birthDate[2..-1]}'"
            else
              # fastest
              # clauses << " resource @> '{ \"birthDate\": \"#{birthDate}\" }'"
              clauses << "to_date(patient.resource ->> 'birthDate', 'YYYY-MM-DD') = '#{birthDate}'"
            end
          end
          clauses << "patient.resource #>>'{address,0,city}' = '#{city}'" if city
          if has
            has.each do |chain|
              # ex. chain = [ 'Observation', 'patient', 'code', '8480-6' ]
              clauses << "#{chain[0].downcase}.#{chain[2]} ILIKE '%#{chain[3]}%'"
            end
          end
        end
        query = ['SELECT', selectq, 'FROM', fromq.join(',')].join(' ')
        query += [' WHERE', clauses.join(' AND ')].join(' ') unless clauses.empty?
        query += " ORDER BY patient.id LIMIT #{Candle::Config::CONFIGURATION['page_size']}"
        count = ['SELECT', countq, 'FROM', fromq.join(',')].join(' ')
        count += [' WHERE', clauses.join(' AND ')].join(' ') unless clauses.empty?
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
            bundle.entry << Candle::Helpers.bundle_entry("#{request.base_url}/fhir/Patient/#{id}", resource)
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
