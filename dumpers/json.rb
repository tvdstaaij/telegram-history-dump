require 'json'
require_relative 'lib/single_file_line_dumper'

class JsonDumper < SingleFileLineDumper

  def dump_msg(dialog, msg)
    @stream.puts(JSON.generate(msg))
  end

  def get_file_extension
    '.jsonl'
  end

  def get_output_type
    'json'
  end

end

Dumper = JsonDumper
