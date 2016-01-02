require_relative '../single_file_line_dumper'

class BareDumper < SingleFileLineDumper

  def dump_msg(dialog, msg)
    @stream.puts(msg['text']) if msg['text']
  end

  def get_file_extension
    '.txt'
  end

end

Dumper = BareDumper
