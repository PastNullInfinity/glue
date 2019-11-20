require 'spec_helper'
require 'dotenv'
require 'glue'
require 'glue/event'
require 'glue/tracker'
require 'glue/finding'
require 'glue/reporters'
require 'glue/reporters/slack_reporter'

def load_env(path)
env_vars_path = 'spec/reporters/env_variables/'
 # Stubs ENV with generic GIT variables
 Dotenv.load("#{env_vars_path}.#{path}.env")
end
describe Glue::SlackReporter do
  before :each do
    @tracker = Glue::Tracker.new(
      slack_token: 'thisisatotallytruetok3n',
      slack_channel: 'glue_channel',
      appname: 'test_app'
    )
    @tracker.report Glue::Finding.new('finding_appname',
                                      'finding_description',
                                      'finding_detail',
                                      'finding_test',
                                      1,
                                      'fingerprint_1',
                                      'finding_task')
  end

  describe '.Slack Reporter', slack_mock: true do
    it 'Should report findings as a slack message with an attachment' do
      load_env('slack_reporter_Jenkins')
      @slack = Glue::SlackReporter.new
      @slack.run_report(@tracker)
      # Check slack client made request to send message with attachment for findings
      expect(WebMock).to (have_requested(:post, 'https://slack.com/api/chat.postMessage')
        .with do |req|
                            req.body.include?('attachments=%0A%09Description%3A+finding_description')
                            req.body.include?('text=OWASP+Glue+has+found+1+vulnerabilities')
                          end)
    end
  end
end
