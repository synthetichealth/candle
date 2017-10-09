require './test/test_helper'
require './lib/observation'

class ObservationTest < SequelTestCase
  def setup
    patient_json = File.read('./test/fixtures/patient1.json')
    Candle::Patient.create(patient_json)
    @patient_id = DB[:patient].first[:id]
  end


  def test_create
    assert_equal 0, DB[:observation].count
    observation_json = File.read('./test/fixtures/observation1.json')
    response = Candle::Observation.create(observation_json, @patient_id, nil)
    assert_equal 201, response[0]
    assert_equal 1, DB[:observation].count
  end

  def test_read
    observation_json = File.read('./test/fixtures/observation1.json')
    Candle::Observation.create(observation_json, @patient_id, nil)
    id = DB[:observation].first[:id]
    response = Candle::Observation.read(id)
    assert_equal 200, response[0]
    response_json = JSON.parse(response[2])
    assert_equal 'Body Height', response_json['code']['text']
  end
end
