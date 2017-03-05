require 'json'

class JsonLinesDumpReader

  def initialize(filename)
    @filename = filename
    @stream = nil
  end

  def start
    @stream = File.open(@filename, 'r:UTF-8')
  end

  def read_msg
    json_str = @stream.gets
    json_str ? JSON.parse(json_str) : nil
  end

  def end
    @stream.close if @stream
  end

end
