require './test/test_helper'
require 'minitest/autorun'
require './lib/patient'

class PatientTest < SequelTestCase

  def test_create
    assert_equal 0, DB[:patient].count
    patient_json = File.read('./test/fixtures/patient1.json')
    response = Candle::Patient.create(patient_json)
    assert_equal 201, response[0]
    assert_equal 1, DB[:patient].count
  end

end
