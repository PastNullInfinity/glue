require 'open3'
require 'pathname'
require 'digest'

#
# Glue miscellaneous helper utilities that are common to multiple classes
#
module Glue::Util
  #
  # Determines which kind of build environment Glue is running. It supports Jenkins and Bitbucket
  #
  # @return [<String>] <Environment type>
  #
  def which_env?
    if ENV['BITBUCKET_COMMIT'].nil? && ENV['GIT_COMMIT'].nil?
      nil
    elsif !ENV['BITBUCKET_COMMIT'].nil?
      'bitbucket'
    else
      'jenkins'
    end
  end

  #
  # Runs command inside shell and consumes the output
  #
  # @param [<Type>] report report object
  # @param [<Type>] *splat command line args
  #
  # @return [<String>] command output
  #
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

  #
  # Generates SHA256 fingerprint for finding
  #
  # @param [<String>] text <Single finding>
  #
  # @return [<String>] <Fingerprint>
  #
  def fingerprint(text)
    Digest::SHA2.new(256).update(text).to_s
  end

  def strip_archive_path(path, delimeter)
    path.split(delimeter).last.split('/')[1..-1].join('/')
  end

  #
  # Generates relative path from current working directory
  #
  # @param [<Pathname>] path <Path to file>
  # @param [<Pathname>] pwd <Current working directory>
  #
  # @return [<Path>] <Relative path from pwd>
  #
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

  def task?(task_name, tracker)
    if tracker.options[:run_tasks].include? task_name
      true
    else
      false
    end
  rescue Exception::NoMethodError
    false
  end

  def label?(label_name, tracker)
    if tracker.options[:labels].include? label_name
      true
    else
      false
    end
  rescue Exception::NoMethodError
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

  def repository_linker(finding)
    filepath = get_finding_path(finding)
    linenumber = finding.source[:line]
    case get_environment_vars
    when 'bitbucket'
      "https://bitbucket.org/#{ENV['BITBUCKET_REPO_FULL_NAME']}/src/#{ENV['BITBUCKET_COMMIT']}/#{filepath}#lines-#{linenumber}"
    when 'jenkins'
      "#{ENV['GIT_URL'].gsub('git@', '').gsub(':', '/').gsub('.git', '').insert(0, 'https://')}/src/#{ENV['GIT_COMMIT']}/#{filepath}#lines-#{linenumber}"
    when nil
      ''
    end
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
