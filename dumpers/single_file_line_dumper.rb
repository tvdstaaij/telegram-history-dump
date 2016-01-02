require_relative 'dumper_interface'

class SingleFileLineDumper < DumperInterface

  def start_dialog(dialog, progress)
    @state = progress.dumper_state ? progress.dumper_state.clone : {}
    outfile = @state['outfile']
    if outfile
      @prepender = DumpPrepender.new(outfile)
    else
      safe_name = get_safe_name(dialog['print_name'])
      outfile = File.join(get_backup_dir, safe_name + get_file_extension)
      @state['outfile'] = outfile
    end
    @stream = File.open(outfile, 'w')
  end

  def end_dialog(dialog)
    @stream.close
    @stream = nil
    @prepender.merge if @prepender
    @state
  end

  def get_file_extension
    raise 'get_file_extension must be implemented'
  end

end
