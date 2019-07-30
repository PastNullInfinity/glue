require 'open3'
require 'pathname'
require 'digest'

module Glue::Util


  def runsystem(report, *splat)
    Open3.popen3(*splat) do |stdin, stdout, stderr, wait_thr|
      
      # start a thread consuming the stdout buffer
      # if the pipes fill up a deadlock occurs
      stdout_consumed = ""
      consumer_thread = Thread.new {
        while line = stdout.gets do
          stdout_consumed += line
        end
      }
      
      if $logfile and report
        while line = stderr.gets do
          $logfile.puts line
        end
      end

      consumer_thread.join
      return stdout_consumed.chomp
      #return stdout.read.chomp
    end
  end

  def fingerprint text
    Digest::SHA2.new(256).update(text).to_s
  end

  def strip_archive_path path, delimeter
    path.split(delimeter).last.split('/')[1..-1].join('/')
  end

  def relative_path path, pwd
    pathname = Pathname.new(path)
    return path if pathname.relative?
    pathname.relative_path_from(Pathname.new pwd)
  end

  def number?(str)
    true if Float(str)
  rescue StandardError
    false
  end

  def get_finding_path(finding)
    pathname_regex = Regexp.new(/(\.\/|#<Pathname:)(?<file_path>.*)(?<file_ext>\.py|\.java|\.class|\.js|\.ts|.xml)(>)?/i)
    unless ENV['BITBUCKET_REPO_FULL_NAME'].nil?
      if !finding.source[:file].to_s.match(pathname_regex).nil?
        matches = finding.source[:file].match(pathname_regex)
        matches[:file_path] + matches[:file_ext]
      else finding.source[:file].to_s
      end
    else
      ENV['BITBUCKET_REPO_FULL_NAME']
    end
  end

  def bitbucket_linker(finding)
    filepath = get_finding_path(finding)
    linenumber = finding.source[:line]
    unless ENV['BITBUCKET_REPO_FULL_NAME'].nil?
      "https://bitbucket.org/#{ENV['BITBUCKET_REPO_FULL_NAME']}/src/#{ENV['BITBUCKET_COMMIT']}/#{filepath}#lines-#{linenumber}"
    else 
      "https://bitbucket.org"
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
