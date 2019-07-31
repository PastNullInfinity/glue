# frozen_string_literal: true

require 'glue/finding'
require 'glue/reporters/html_reporter'
require 'glue/util'

# Takes in input from an ERB template and exports to PDF via wkhtmltopdf.
# Inherits the HTML template from the HTML Reporter
class Glue::PDFReporter < Glue::HTMLReporter 
  Glue::Reporters.add self
  include Glue::Util
  attr_accessor :name, :format

  def initialize
    @name = 'PDFReporter'
    @format = :to_pdf
    @currentpath = __dir__
  end

  def run_report(tracker)
    html = to_html(tracker)
    Glue.notify '**** Rendering PDF'
    File.open("#{tracker.options[:appname]}.html", 'w+') { |f| f.write html.join("\n") }
    # Runs command to render to PDF
    `wkhtmltopdf --encoding utf-8 #{tracker.options[:appname]}.html #{tracker.options[:appname]}.pdf` 
    Glue.notify "**** Saved PDF to #{tracker.options[:appname]}.pdf"
  end
end
