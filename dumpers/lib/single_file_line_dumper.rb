require 'fileutils'
require_relative 'dumper_interface'

class SingleFileLineDumper < DumperInterface

  def start_dialog(dialog, progress)
    @prepender = nil
    @rename_to = nil
    @output_dir = File.join(get_backup_dir, get_output_type)
    @state = progress.dumper_state ? progress.dumper_state.clone : {}
    output_basename = $config['friendly_data_filenames'] == false ?
      dialog['id'].to_s : get_safe_name(dialog['print_name'])
    output_filename = output_basename + get_file_extension
    @current_outfile = @state['outfile']
    if @current_outfile
      current_basename = File.basename(@current_outfile, get_file_extension)
      @rename_to = output_filename if current_basename != output_basename
      @current_outfile = File.join(get_backup_dir, @current_outfile)
      @prepender = DumpPrepender.new(@current_outfile)
    else
      FileUtils.mkdir_p(@output_dir)
      @current_outfile = File.join(@output_dir, output_filename)
      @state['outfile'] = relativize_output_path(@current_outfile)
    end
    @stream = File.open(@current_outfile, 'w:UTF-8')
  end

  def end_dialog(dialog)
    @stream.close
    @stream = nil
    @prepender.merge if @prepender
    if @rename_to && $config['update_data_filenames']
      new_outfile = File.join(@output_dir, @rename_to)
      begin
        FileUtils.mv(@current_outfile, new_outfile)
        @state['outfile'] = relativize_output_path(new_outfile)
      rescue SystemCallError => e
        $log.error('Could not rename %s to %s (error %d), '\
                   'leaving filename intact' % [
          @state['outfile'], relativize_output_path(new_outfile), e.errno
        ])
      end
    end
    @state
  end

  def get_file_extension
    raise 'get_file_extension must be implemented'
  end

end
