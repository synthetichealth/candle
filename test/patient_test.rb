require './test/test_helper'
require './lib/patient'

class PatientTest < SequelTestCase

  def test_create
    assert_equal 0, DB[:patient].count
    patient_json = File.read('./test/fixtures/patient1.json')
    response = Candle::Patient.create(patient_json)
    assert_equal 201, response[0]
    assert_equal 1, DB[:patient].count
  end

  def test_read
    patient_json = File.read('./test/fixtures/patient1.json')
    Candle::Patient.create(patient_json)
    id = DB[:patient].first[:id]
    response = Candle::Patient.read(id)
    assert_equal 200, response[0]
    response_json = JSON.parse(response[2])
    assert_equal 'Abernathy195', response_json['name'][0]['family']
  end
end
