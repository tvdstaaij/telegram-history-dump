require_relative '../dumper_interface'

class BareDumper < DumperInterface

  def start_dialog(dialog)
    safe_name = get_safe_name(dialog['print_name'])
    outfile = File.join(get_backup_dir, safe_name + '.txt')
    @stream = File.open(outfile, 'w')
  end

  def dump_msg(dialog, msg)
    @stream.puts(msg['text']) if msg['text']
  end

  def end_dialog(dialog)
    @stream.close
    @stream = nil
  end

end

Dumper = BareDumper
