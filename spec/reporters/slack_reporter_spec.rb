require 'pathname'
require 'glue'
require 'glue/event'
require 'glue/tracker'
require 'glue/finding'
require 'glue/reporters'
require 'glue/reporters/slack_reporter'

context Glue::SlackReporter do
  class UtilClass end
  before(:each) do
    @env_class = UtilClass.new
    @env_class.extend(Glue::Util)
  end

  let(:pdf) { Pathname.new('report_test_app.html') }
  let(:html) { Pathname.new('report_test_app.pdf') }

  before :each do
    @tracker = Glue::Tracker.new(
      slack_token: 'thisisatotallytruetok3n',
      slack_channel: 'glue_channel',
      appname: 'test_app'
    )
    @tracker.report Glue::Finding.new('finding_appname',
                                      'finding_description',
                                      'finding_detail',
                                      { file: 'test/testfile.py' },
                                      1,
                                      'fingerprint_1',
                                      'finding_task')

    stub_env('GIT_COMMIT', 'testJenkinsCommit')
    stub_env('GIT_BRANCH', 'origin/master')
    stub_env('GIT_URL', 'git@bitbucket.org:testfolder/testrepo.git')
    stub_env('JOB_NAME', 'job_folder/PR-1/master')
    @slack = Glue::SlackReporter.new
  end

  describe '.Slack Reporter', slack_mock: true do
    it 'Should report findings as a slack message with an attachment' do
      # Stubs the call to wkhtmltopdf
      allow(@UtilClass).to receive(:runsystem).with('wkhtmltopdf --encoding utf-8 report_test_app.html report_test_app.pdf').and_return('test')

      # Runs the report generator
      @slack.run_report(@tracker)

      # Check slack client made request to send message with attachment for findings
      expect(WebMock).to (have_requested(:post, 'https://slack.com/api/chat.postMessage').with do |req|
        req.body.include?('attachments=%0A%09Description%3A+finding_description')
        req.body.include?('text=OWASP+Glue+has+found+1+vulnerabilities')
      end)
    end

    it 'Should produce a PDF and HTML output', type: :aruba do
      expect(pdf).to be_file
      expect(html).to be_file
    end

    # it 'Should skip report generation if there are no issues', slack_mock: true do
    #   stub_env('GIT_COMMIT', 'testJenkinsCommit')
    #   stub_env('GIT_BRANCH', 'origin/master')
    #   stub_env('GIT_URL', 'git@bitbucket.org:testfolder/testrepo.git')
    #   stub_env('JOB_NAME', 'job_folder/PR-1/master')
    #   @slack = Glue::SlackReporter.new
    #   @tracker.report Glue::Finding.new('finding_appname',
    #                                     'finding_task')

    #   expect(@slack.run_report).to receive(tracker).with(@tracker).to eq('**** No issues found, skipping send report.')
    # end
  end
end
