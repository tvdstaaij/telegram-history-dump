require 'fileutils'
require_relative 'dumper_interface'

class SingleFileLineDumper < DumperInterface

  def start_dialog(dialog, progress)
    @prepender = nil
    @state = progress.dumper_state ? progress.dumper_state.clone : {}
    output_file = @state['outfile']
    if output_file
      output_file = File.join(get_backup_dir, output_file)
      @prepender = DumpPrepender.new(output_file)
    else
      filename = get_safe_name(dialog['print_name']) + get_file_extension
      output_dir = File.join(get_backup_dir, get_output_type)
      FileUtils.mkdir_p(output_dir)
      output_file = File.join(output_dir, filename)
      @state['outfile'] = relativize_output_path(output_file)
    end
    @stream = File.open(output_file, 'w:UTF-8')
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
