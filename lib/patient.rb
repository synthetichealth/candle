require 'pry'
module Candle
  class Patient
    RACE_EXT = 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-race'.freeze
    ETHNICITY_EXT = 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-ethnicity'.freeze

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
          name = patient.name.map{|name| [name.text, name.family, name.given].flatten.compact.join(' ')}.compact.join(' ')
          race = patient.extension.find{|x| x.url == RACE_EXT}
                        .extension.find{|x| x.url == 'ombCategory'}.valueCoding.code rescue nil
          ethnicity = patient.extension.find{|x| x.url == ETHNICITY_EXT}
                        .extension.find{|x| x.url == 'ombCategory'}.valueCoding.code rescue nil
          patient.id = nil
          resource = patient.to_json
          id = DB[:patient].insert(name: name, race: race, ethnicity: ethnicity, resource: resource)
          patient.id = id.to_s
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
        end
      end
      # Return the results
      headers = Hash.new.merge(Candle::Config::CONTENT_TYPE)
      headers['location'] = response_location if response_location
      [response_code, headers, response_body]
    end

    def self.read(id)
      return [404, Candle::Config::CONTENT_TYPE, nil] if id.to_i == 0
      begin
        patient_row = DB[:patient].select(:resource).first(id: id)
        if patient_row
          response_code = 200
          patient = FHIR.from_contents(patient_row[:resource])
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
      end
      [response_code, Candle::Config::CONTENT_TYPE, response_body]
    end

    def self.search(request, params)
      name = params['name']
      gender = params['gender']
      birthDate = params['birthdate']
      race = params['race']
      ethnicity = params['ethnicity']
      city = params['address-city']
      has = []
      params.each do |key, value|
        if key.start_with?('_has')
          has << key.split(':')[1..-1]
          has.last << value
        end
      end
      page_raw = params['page']
      page_given = !page_raw.nil?
      page = (page_raw.to_i rescue 0)
      page = 0 if page < 0
      params.delete('page')
      begin
        query = DB[:patient].select(Sequel.qualify('patient', 'resource'), Sequel.qualify('patient', 'id'))
        patient = nil
        if has
          query = query.distinct(:id)
        end
        query = query.where(Sequel.lit('patient.id > ?', page))
        unless params.empty?
          resource_jsonb = Sequel.pg_jsonb_op(Sequel.qualify('patient', 'resource'))
          query = query.where(race: race) if race
          query = query.where(ethnicity: ethnicity) if ethnicity
          query = query.where(Sequel.ilike(:name, "%#{name}%")) if name
          query = query.where(resource_jsonb.get_text('gender') => gender) if gender
          if birthDate
            if birthDate.start_with?('eq')
              query = query.where("to_date(patient.resource ->> 'birthDate', 'YYYY-MM-DD') = ?", birthDate[2..-1])
            elsif birthDate.start_with?('ge')
              query = query.where("to_date(patient.resource ->> 'birthDate', 'YYYY-MM-DD') >= ?", birthDate[2..-1])
            else
              # fastest
              # clauses << " resource @> '{ \"birthDate\": \"#{birthDate}\" }'"
              query = query.where("to_date(patient.resource ->> 'birthDate', 'YYYY-MM-DD') = ?", birthDate)
            end
          end
          query = query.where(resource_jsonb.get_text(['{address,0,city}']) => city) if city
          if has
            has.each do |chain|
              query = query.left_join(chain[0].downcase.to_sym, patient: :id)
              query = query.where(Sequel.ilike(Sequel.qualify(chain[0].downcase, chain[2]), "%#{chain[3]}%"))
            end
          end
        end

        count_query = query.dup
        query = query.limit(100)
        bundle = FHIR::Bundle.new({'type'=>'searchset','total'=>0})
        page_total = 0
        start = Time.now
        bundle.total = count_query.count
        query.each do |row|
          id = row[:id]
          json = row[:resource]
          resource = FHIR.from_contents(json)
          resource.id = id
          bundle.entry << Candle::Helpers.bundle_entry("#{request.base_url}/fhir/Patient/#{id}", resource)
        end
        bundle.link << FHIR::Bundle::Link.new({'relation': 'self', 'url': request.url})
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
      end
      [response_code, Candle::Config::CONTENT_TYPE, response_body]
    end
  end
end
