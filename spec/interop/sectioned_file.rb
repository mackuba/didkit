# frozen_string_literal: true

class SectionedFile
  def initialize(filename)
    @sections = {}
    section = nil

    File.foreach(File.join(__dir__, filename), chomp: true) do |line|
      next if line.strip.empty?

      if line.start_with?('#')
        name = line.delete_prefix('#').strip
        section = @sections[name] = []
      elsif section
        section << line
      end
    end
  end

  def get(name)
    @sections[name]
  end
end
