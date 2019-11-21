require 'glue'
require 'glue/event'
require 'glue/tracker'
require 'glue/finding'
require 'glue/util'

describe '.slack_priority' do
  include Glue::Util
  it 'Should return a string' do
    expect(slack_priority(1)).to be_a_kind_of(String)
  end
  it 'Should return a string if the severity is a string' do
    expect(slack_priority('1')).to be_a_kind_of(String)
  end
  it 'Should return danger on 1' do
    expect(slack_priority).to receive(1).and to_return('danger')
  end
  it 'Should return warning on 2' do
    expect(slack_priority).to receive(2).and to_return('warning')
  end
  it 'Should return good on 3' do
    expect(slack_priority.to receive(3).and to_return('good')
  end
  it 'Should return an empty string on unknown severity' do
    expect(slack_priority(12)).to eq('')
  end
end

describe '.number?' do
  include Glue::Util
  it 'Should return true if input is a type of Number' do
    expect(number?(1)).to eq(true)
  end
  it 'Should return false otherwise' do
    expect(number?('asdf')).to eq(false)
  end
  it 'Should return false if an exception occurs' do
    expect(number?('asdf')).to receive(StandardError) && eq(false)
  end
end

describe '.fingerprint' do
  include Glue::Util
  it 'Should return different hashes for different inputs' do
    expect(fingerprint('I heard that bubblegum is coming back in style')).not_to eq(fingerprint('I am your father'))
  end
end
