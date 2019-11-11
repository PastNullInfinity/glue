
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

PATHNAME_REGEX = %r{(\.\/|#<Pathname:)(?<file_path>.*)(?<file_ext>\.py|\.java|\.class|\.js|\.ts|.xml)(>)?}

class Glue::SlackReporter < Glue::BaseReporter
  Glue::Reporters.add self
  include Glue::Util

  attr_accessor :name, :format

  def initialize
    @name = 'SlackReporter'
    @format = :to_slack
    @currentpath = __dir__
    # OWASP Dependency Check specific settings
    if is_label?('java',@tracker) || is_task?('owaspdependencycheck',@tracker)
      @sbt_path = @tracker.options[:sbt_path]
      @scala_project = @tracker.options[:scala_project]
      @gradle_project = @tracker.options[:gradle_project]
      @maven_project = @tracker.options[:maven_project]
    end
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

    begin
      if ENV['BITBUCKET_COMMIT'].nil? #If nil, we're probably inside a Jenkins build
        Glue.warn "***** No Bitbucket variables found, is this a Jenkins build?"
        commit = ENV['GIT_COMMIT']
        Glue.warn commit
        branch = ENV['GIT_BRANCH'].chomp("origin/")
        Glue.warn branch
        url = ENV['GIT_URL'].gsub("git@","").gsub(":","/").gsub(".git","").insert(0,"https://")
      elsif ENV['GIT_COMMIT'].nil?
        commit = ENV['BITBUCKET_COMMIT']
        branch = ENV['BITBUCKET_BRANCH']
        url = 'https://bitbucket.com/' + ENV['BITBUCKET_REPO_FULL_NAME']
      else
        Glue.warn "***** No Git enviroment variables found, the report will be generated with broken links"
      end
    end

    reports = []
    if tracker.findings.length < 5
      tracker.findings.each do |finding|
        reports << get_slack_attachment_json(finding, tracker)
      end
    elsif tracker.findings.length ==0
      Glue.notify '**** No issues found, skipping report generation...'
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
      issue_number = tracker.findings.length
      if tracker.findings.length == 0
        Glue.notify '**** No issues found, skipping send report.'
      elsif tracker.findings.length < 5
        client.chat_postMessage(
          channel: tracker.options[:slack_channel],
          text: 'OWASP Glue has found ' + issue_number.to_s + \
                ' vulnerabilities in *' + tracker.options[:appname] + '* :' + commit + ".\n" \
                "Here's a summary: \n Link to repo: #{url}/commits/#{commit}",
          attachments: reports,
          as_user: post_as_user
        )
      else
        Glue.notify '**** Uploading message and attachment to Slack'
        client.chat_postMessage(
          channel: tracker.options[:slack_channel],
          text: 'OWASP Glue has found ' + issue_number.to_s + ' vulnerabilities in *' + tracker.options[:appname] + "* : #{commit} . \n Here's a summary: \n Link to repo: #{url}/commits/#{commit}",
          as_user: post_as_user
        )
        client.files_upload(
          channels: tracker.options[:slack_channel],
          as_user: true,
          file: Faraday::UploadIO.new("#{report_filename}.pdf", 'pdf'),
          filetype: 'pdf',
          filename: "#{tracker.options[:appname]}.pdf"
        )
        # if @tracker[:labels].include? 'java' or @tracker[:tasks].include? 'owaspdependencycheck'
        #   path = if @scala_project
        #     #md = @result.match(/\e\[0m\[\e\[0minfo\e\[0m\] \e\[0mWriting reports to (?<report_path>.*)\e\[0m/)
        #     #md[:report_path] + "/dependency-check-report.xml"
        #     report_directory = @sbt_settings.match(/.*dependencyCheckOutputDirectory: (?<report_path>.*)\e\[0m/)
        #     report_directory[:report_path] + "/dependency-check-report.xml"
        #   elsif @gradle_project
        #     @trigger.path + "/build/reports/dependency-check-report.xml"
        #   elsif @maven_project
        #     @trigger.path + "target/dependency-check-report.xml"
        #   else
        #     @trigger.path + "/dependency-check-report.xml"
        #   end
        #   client.files_upload(
        #     channels: tracker.options[:slack_channel],
        #     as_user: true,
        #     file: Faraday::UploadIO.new("#{report_filename}.pdf", 'pdf'),
        #     filetype: 'pdf',
        #     filename: "dep_check_#{tracker.options[:appname]}.pdf"
        #   )
        # end
      end
    rescue Slack::Web::Api::Error => e
      Glue.fatal 'Post to slack failed: ' << e.to_s
    rescue StandardError => e
      Glue.fatal '***** Unknown error: ' << e.to_s
    end
  end
end
