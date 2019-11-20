require 'open3'
require 'pathname'
require 'digest'

module Glue::Util
  def runsystem(report, *splat)
    Open3.popen3(*splat) do |_stdin, stdout, stderr, _wait_thr|
      Glue.debug "**** CLI: #{splat.join(' ').chomp}"

      # start a thread consuming the stdout buffer
      # if the pipes fill up a deadlock occurs
      stdout_consumed = ''
      consumer_thread = Thread.new do
        while line = stdout.gets
          stdout_consumed += line
        end
      end

      if $logfile && report
        while line = stderr.gets
          $logfile.puts line
        end
      end

      consumer_thread.join
      return stdout_consumed.chomp
      # return stdout.read.chomp
    end
  end

  def fingerprint(text)
    Digest::SHA2.new(256).update(text).to_s
  end

  def strip_archive_path(path, delimeter)
    path.split(delimeter).last.split('/')[1..-1].join('/')
  end

  def relative_path(path, pwd)
    pathname = Pathname.new(path)
    return path if pathname.relative?

    pathname.relative_path_from(Pathname.new(pwd))
  end

  def number?(str)
    true if Float(str)
  rescue StandardError
    false
  end

  def is_task?(task_name, tracker)
    if tracker.options[:run_tasks].include? task_name
      true
    else
      false
    end
  rescue NoMethodError
    false
  end

  def is_label?(label_name, tracker)
    if tracker.options[:labels].include? label_name
      true
    else
      false
    end
  rescue NoMethodError
    false
  end

  def get_finding_path(finding)
    pathname_regex = Regexp.new(%r{(\./|#<Pathname:)(?<file_path>.*)(?<file_ext>\.py|\.java|\.class|\.js|\.ts|.xml)(>)?}i)
    # unless !ENV['BITBUCKET_REPO_FULL_NAME'].nil?
    if finding.source[:file].to_s.match(pathname_regex).nil? finding.source[:file].to_s
    else
      matches = finding.source[:file].match(pathname_regex)
      matches[:file_path] + matches[:file_ext]
    end
    # else
    #   ENV['BITBUCKET_REPO_FULL_NAME']
    # end
  end

  def bitbucket_linker(finding)
    filepath = get_finding_path(finding)
    linenumber = finding.source[:line]
    if ENV['BITBUCKET_REPO_FULL_NAME'].nil? # we are probably inside Jenkins
      "#{ENV['GIT_URL'].gsub('git@', '').gsub(':', '/').gsub('.git', '').insert(0, 'https://')}/src/#{ENV['GIT_COMMIT']}/#{filepath}#lines-#{linenumber}"
    else
      "https://bitbucket.org/#{ENV['BITBUCKET_REPO_FULL_NAME']}/src/#{ENV['BITBUCKET_COMMIT']}/#{filepath}#lines-#{linenumber}"
    end
  end

  def bitbucket_pr_linker(pr_number, project_name)
    # The link should be something like:
    # https://bitbucket.org/<project_name>/<repo_name>/pull-requests/<pr_number>/
  end

  def get_git_environment
    git_env = {}
    if ENV['GIT_COMMIT'].nil? && ENV['BITBUCKET_COMMIT'].nil?
      Glue.warn '***** No Git enviroment variables found, the report will be generated with broken links'
      git_env[:commit] = git_env[:branch] = git_env[:url] = ''
    end
    unless ENV['GIT_COMMIT'].nil? # If nil, we're probably inside a Jenkins build
      Glue.warn '***** No Bitbucket variables found, is this a Jenkins build?'
      git_env[:commit] = ENV['GIT_COMMIT']
      Glue.warn git_env[:commit]
      git_env[:branch] = ENV['GIT_BRANCH'].sub('origin/', '')
      Glue.warn git_env[:branch]
      if git_env[:branch].include? 'PR'
        Glue.warn '***** This build comes from a Bitbucket Pull Request, the link will point to that.'
        git_env[:url] = bitbucket_pr_linker(git_env.branch.chomp('PR-'), ENV['JOB_NAME'])
      else
        git_env[:url] = ENV['GIT_URL'].gsub('git@', '').gsub(':', '/').gsub('.git', '').insert(0, 'https://')
      end
    end
    unless ENV['BITBUCKET_COMMIT'].nil?  # If nil, we're probably inside a Bitbucket pipeline
      Glue.warn '***** No Jenkins variables found, is this a Bitbucket build?'
      git_env[:commit] = ENV['BITBUCKET_COMMIT']
      git_env[:branch] = ENV['BITBUCKET_BRANCH'].sub('origin/', '')
      git_env[:url] = 'https://bitbucket.org/' + ENV['BITBUCKET_REPO_FULL_NAME']
    end
    git_env
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
end
