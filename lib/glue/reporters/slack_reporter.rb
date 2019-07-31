# frozen_string_literal: true

require 'faraday'
require 'glue/finding'
require 'glue/reporters/base_reporter'
require 'jira-ruby'
require 'slack-ruby-client'
require 'glue/util'
# In IRB
# require 'slack-ruby-client'
# Slack.configure do |config|
#   config.token = "token"
# end
# client = Slack::Web::Client.new
# client.chat_postMessage(channel: 'channel_name', text: "message_text", attachments: json_attachment, as_user: post_as_user)

class Glue::SlackReporter < Glue::BaseReporter
  Glue::Reporters.add self
  include Glue::Util

  attr_accessor :name, :format

  def initialize
    @name = 'SlackReporter'
    @format = :to_slack
    @currentpath = __dir__
  end

  def get_slack_attachment_json(finding, tracker)
    Glue.notify '**** Generating report data'
    json = {
      "fallback": 'Results of OWASP Glue test for repository' + tracker.options[:appname] + ':',
      "color": slack_priority(finding.severity),
      "title": finding.description.to_s,
      "title_link": finding.detail.to_s,
      "text": finding.detail.to_s
    }
  end

  def get_slack_attachment_text(finding, _tracker)
    Glue.notify '**** Generating text attachment'
    text =
      'Link: ' + bitbucket_linker(finding) + "\n" \
      'Vulnerability: ' + finding.description.to_s + "\n" \
      'Severity:' + slack_priority(finding.severity).to_s + " \n" \
      'Detail: ' + "\n" + finding.detail.to_s << "\n"
  end

  def run_report(tracker)
    post_as_user = false unless tracker.options[:slack_post_as_user]

    mandatory = %i[slack_token slack_channel]
    missing = mandatory.select { |param| tracker.options[param].nil? }
    unless missing.empty?
      Glue.fatal "missing one or more required params: #{missing}"
      return
    end

    Slack.configure do |config|
      config.token = tracker.options[:slack_token]
    end

    client = Slack::Web::Client.new

    begin
      client.auth_test
    rescue Slack::Web::Api::Error => e
      Glue.fatal 'Slack authentication failed: ' << e.to_s
    end

    reports = []
    if tracker.findings.length < 5
      tracker.findings.each do |finding|
        reports << get_slack_attachment_json(finding, tracker)
      end
    else
      Glue.notify '**** Running base HTML report'
      reports = []
      report_filename = "report_#{tracker.options[:appname]}"

      template = ERB.new File.read("#{@currentpath}/html_template.erb")
      Glue.notify '**** Rendering HTML'
      reports << template.result(binding) # ZOZZISSIMO TODO Da sistemare il binding

      File.open("#{report_filename}.html", 'w+') { |f| f.write reports.join("\n") }

      # runs command to render to PDF
      Glue.notify '**** Rendering PDF'
      `wkhtmltopdf --encoding utf-8 #{report_filename}.html #{report_filename}.pdf`
    end

    puts tracker.options[:slack_channel]

    begin
      Glue.notify '**** Uploading message to Slack'

      if tracker.findings.length < 5
        client.chat_postMessage(
          channel: tracker.options[:slack_channel],
          text: 'OWASP Glue has found ' + tracker.findings.length +
                'vulnerabilities in *' + tracker.options[:appname] + '* :' + ENV['BITBUCKET_COMMIT'] + ".\n" \
                "Here's a summary: \n Link to repo:" + 
                'https://bitbucket.com/' + ENV['BITBUCKET_REPO_FULL_NAME'] + '/commits/' + ENV['BITBUCKET_COMMIT'],
          attachments: reports,
          as_user: post_as_user
        )
      else

        client.chat_postMessage(
          channel: tracker.options[:slack_channel],
          text: 'OWASP Glue has found ' + reports.length.to_s + ' vulnerabilities in *' + tracker.options[:appname] + "* : #{ENV['BITBUCKET_COMMIT']} . \n Here's a summary: \n Link to repo: https://bitbucket.com/#{ENV['BITBUCKET_REPO_FULL_NAME']}/commits/#{ENV['BITBUCKET_COMMIT']}",
          as_user: post_as_user
        )
        client.files_upload(
          channels: tracker.options[:slack_channel],
          as_user: true,
          file: Faraday::UploadIO.new("#{report_filename}.pdf", 'pdf'),
          filetype: 'pdf',
          filename: 'report_' + tracker.options[:appname]
        )
      end
    rescue Slack::Web::Api::Error => e
      Glue.fatal 'Post to slack failed: ' << e.to_s
    rescue StandardError => e
      Glue.fatal '***** Unknown error: ' << e.to_s
    end
  end
end
