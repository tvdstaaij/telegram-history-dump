require 'json'
require 'tempfile'
require_relative 'dumper_base'

class JsonLinesDumper < DumperBase
  OUTPUT_SUBDIR = 'json'
  FILE_EXTENSION = '.jsonl'

  def start_dialog(dialog, progress)
    @progress = progress
    @chunk_buffer = []
    @output_dir = File.join(get_backup_dir, OUTPUT_SUBDIR)
    @state = progress.dumper_state ? progress.dumper_state.clone : {}
    output_basename = $config['friendly_data_filenames'] == false ?
      dialog['id'].to_s : get_safe_name(dialog['print_name'])
    output_filename = output_basename + FILE_EXTENSION
    @current_outfile = @state['outfile']
    if @current_outfile
      current_basename = File.basename(@current_outfile, FILE_EXTENSION)
      @rename_to = output_filename if current_basename != output_basename
      @current_outfile = File.join(get_backup_dir, @current_outfile)
    else
      FileUtils.mkdir_p(@output_dir)
      @current_outfile = File.join(@output_dir, output_filename)
      @state['outfile'] = relativize_output_path(@current_outfile)
    end
  end

  def dump_chunk(dialog, messages)
    tmpfile_prefix = "telegram-history-dump[chunk#{@chunk_buffer.length}]"
    tmpfile = Tempfile.new(tmpfile_prefix, :encoding => 'UTF-8')
    @chunk_buffer.push(tmpfile)
    messages.each { |msg| tmpfile.puts(JSON.generate(msg)) }
  end

  def end_dialog(dialog)
    File.open(@current_outfile, 'a:UTF-8') do |outstream|
      @chunk_buffer.reverse_each do |f|
        f.rewind
        IO.copy_stream(f, outstream)
        f.close!
      end
    end
    @chunk_buffer = nil

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

  def get_output_type
    'json_lines'
  end

end
