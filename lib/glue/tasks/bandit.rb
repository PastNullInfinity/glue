require 'glue/tasks/base_task'
require 'json'
require 'glue/util'
require 'pathname'

class Glue::Bandit < Glue::BaseTask

  Glue::Tasks.add self
  include Glue::Util

  def initialize(trigger, tracker)
    super(trigger, tracker)
    @name = "Bandit"
    @description = "Source analysis for Python"
    @stage = :code
    @labels << "code" << "python"
  end

  def run
    exclude_path = @tracker.options[:bandit_exclude].to_a.join(',').squeeze(',') || "" 
    # binding.pry
    exclude = "-x " + exclude_path unless exclude_path.empty?
    Glue.debug "**** Bandit will not analyze #{exclude_path}"
    rootpath = @trigger.path
    @result=runsystem(true, "bandit",exclude, "-f", "json", "-r", "#{rootpath}")
  end

  def analyze
    begin
      parsed = JSON.parse(@result)
      parsed["results"].each do |warning|
        file = relative_path(warning['filename'], @trigger.path)
        detail = "#{warning['issue_text']}\n#{warning['code']}"
        if ! warning['line']
          warning['line'] = "0"
        end
        if ! warning['code']
          warning['code'] = ""
        end
        source = { :scanner => @name,
                   :file => file,
                   :line => warning['line_number'],
                   :code => warning['test_id'].lstrip }
        report warning["test_name"],
               detail,
               source,
               severity(warning["issue_severity"]),
               fingerprint("#{source}")
      end
    rescue Exception => e
      Glue.warn e.message
      Glue.warn e.backtrace
      Glue.warn "Raw result: #{@result}"
    end
  end

  def supported?
    supported=runsystem(true, "bandit", "-v")
    if supported =~ /command not found/
      Glue.notify "Install python and pip."
      Glue.notify "Run: pip install bandit"
      Glue.notify "See: https://github.com/openstack/bandit"
      return false
    else
      return true
    end
  end

end
