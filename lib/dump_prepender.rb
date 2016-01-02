require 'fileutils'

class DumpPrepender

  def initialize(filename)
    @mainfile = filename
    @tmpfile = filename + '.old'
    FileUtils.mv(@mainfile, @tmpfile)
  end

  def merge
    File.open(@mainfile, 'a') do |outstream|
      IO.copy_stream(@tmpfile, outstream)
    end
    File.delete(@tmpfile)
  end

end
