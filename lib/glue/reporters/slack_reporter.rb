# frozen_string_literal: true

require 'glue/finding'
require 'glue/reporters/base_reporter'
require 'jira-ruby'
require 'slack-ruby-client'
# In IRB
# require 'slack-ruby-client'
# Slack.configure do |config|
#   config.token = "token"
# end
# client = Slack::Web::Client.new
# client.chat_postMessage(channel: 'channel_name', text: "message_text", attachments: json_attachment, as_user: post_as_user)

class Glue::SlackReporter < Glue::BaseReporter
  Glue::Reporters.add self

  attr_accessor :name, :format

  def initialize
    @name = 'SlackReporter'
    @format = :to_slack
  end

  def number?(str)
    true if Float(str)
  rescue StandardError
    false
  end

  def get_slack_attachment_json(finding, _tracker)
    json = {
      "fallback": 'Results of OWASP Glue test for repository' + tracker.options[:appname] + ':',
      "color": slack_priority(finding.severity),
      "title": finding.description.to_s,
      "title_link": finding.detail.to_s,
      "text": finding.detail.to_s
    }
  end

  def get_slack_attachment_text(finding, _tracker)
    text = 'Origin: ' + finding.source.to_s + "\n" \
           'Vulnerability: ' + finding.description.to_s + "\n" \
           'Description: ' + finding.detail.to_s + "\n" \
           'Severity:' + slack_priority(finding.severity).to_s + " \n" \
           'Detail: ' + "\n" + finding.detail.to_s << "\n"
  end

  def slack_priority(severity)
    if number?(severity)
      f = Float(severity)
      if f == 3
        'good'
      elsif f == 2
        'warning'
      elsif f == 1
        'danger'
      else
        Glue.notify "**** Unknown severity type #{severity}"
        severity
      end
    end
  end

  def run_report(tracker)
    post_as_user = false
    post_as_user = true if tracker.options[:slack_post_as_user]

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
    tracker.findings.each do |finding|
      reports << get_slack_attachment_text(finding, tracker)
    end

    puts tracker.options[:slack_channel]

    begin
      client.chat_postMessage(
        channel: tracker.options[:slack_channel],
        text: 'OWASP Glue has found ' + reports.length.to_s + ' vulnerabilities in *' + tracker.options[:appname] + "* . \n Here's a summary:",
        # attachments: reports,
        as_user: post_as_user
      )
      client.files_upload(
        channels: tracker.options[:slack_channel],
        as_user: true,
        content: reports.join,
        filetype: 'auto',
        filename: 'issue_' + tracker.options[:appname]
      )
    rescue Slack::Web::Api::Error => e
      Glue.fatal 'Post to slack failed: ' << e.to_s
    rescue StandardError => e
      Glue.fatal '***** Unknown error: ' << e.to_s
    end
  end
end
