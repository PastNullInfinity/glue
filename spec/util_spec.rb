require 'glue'
require 'glue/event'
require 'glue/tracker'
require 'glue/finding'
require 'glue/util'
context '#Util' do
  # We encapsulate the Util module in a dummy class
  # in order to be able to test it.
  class UtilClass end
  before(:each) do
    @util_class = UtilClass.new
    @util_class.extend(Glue::Util)
  end
  describe '.slack_priority' do
    it 'Should return a string' do
      expect(@util_class.slack_priority(1)).to be_a_kind_of(String)
    end
    it 'Should return a string if the severity is a string' do
      expect(@util_class.slack_priority('1')).to be_a_kind_of(String)
    end
    it 'Should return danger on 1' do
      expect(@util_class.slack_priority(1)).to eq('danger')
    end
    it 'Should return warning on 2' do
      expect(@util_class.slack_priority(2)).to eq('warning')
    end
    it 'Should return good on 3' do
      expect(@util_class.slack_priority(3)).to eq('good')
    end
    it 'Should return an empty string on unknown severity' do
      expect(@util_class.slack_priority(12)).to eq('')
    end
  end

  describe '.number?' do
    it 'Should return true if input is a type of Number' do
      expect(@util_class.number?(1)).to eq(true)
    end
    it 'Should return false otherwise' do
      expect(@util_class.number?('asdf')).to eq(false)
    end
    it 'Should return false if an exception occurs' do
      expect(@util_class.number?('asdf')).to receive(StandardError) && eq(false)
    end
  end
end
