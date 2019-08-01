

require 'glue/finding'
require 'glue/reporters/base_reporter'

class Glue::MarkdownReporter < Glue::BaseReporter
  Glue::Reporters.add self

  attr_accessor :name, :format

  def initialize
    @name = 'MarkdownReporter'
    @format = :to_markdown
  end


  def out(finding)
    
  end

end
