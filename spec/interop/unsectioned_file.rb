# frozen_string_literal: true

class UnsectionedFile
  attr_reader :lines

  def initialize(filename)
    @lines = []

    File.foreach(File.join(__dir__, filename), chomp: true) do |line|
      next if line.strip.empty? || line.start_with?('#')

      @lines << line
    end
  end
end
