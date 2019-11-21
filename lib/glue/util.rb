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

  def slack_priority(severity)
    Float(severity) if number?(severity)
    case severity
    when 3 then return 'good'
    when 2 then return 'warning'
    when 1 then return 'danger'
    else
      Glue.notify "**** Unknown severity type #{severity}"
      severity
    end
    Glue.notify '**** Severity is not a number, returning nothing'
    ''
  end
end
