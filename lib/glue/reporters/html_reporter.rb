
require 'glue/finding'
require 'glue/reporters/base_reporter'
require 'glue/util'

class Glue::HTMLReporter < Glue::BaseReporter
  Glue::Reporters.add self
  include Glue::Util
  attr_accessor :name, :format

  def initialize
    @name = 'HTMLReporter'
    @format = :to_html
    @currentpath = __dir__
    # @template = ERB.new File.read("#{currentpath}/html_template.erb")
  end

  def run_report(tracker)
    Glue.notify 'Running base HTML report...'
    reports = []
    template = ERB.new File.read("#{@currentpath}/html_template.erb")
    reports << template.result(binding)
  end

  def to_html(tracker)
    Glue.notify 'Running base HTML report...'
    reports = []
    template = ERB.new File.read("#{@currentpath}/html_template.erb")
    reports << template.result(binding)
  end
end
