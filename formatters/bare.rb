require_relative 'lib/formatter_base'

class BareFormatter < FormatterBase

  NAME = 'bare'

  def start_backup(dialogs)
    FileUtils.remove_dir(output_dir, true)
    FileUtils.mkdir_p(output_dir)
  end

  def start_dialog(dialog, progress)
    safe_name = get_safe_name(dialog['print_name'])
    output_file = File.join(output_dir, safe_name + '.txt')
    begin
      @stream = File.open(output_file, 'w:UTF-8')
    rescue StandardError => e
      $log.error('Failed to open output file: %s' % e)
    end
  end

  def format_message(dialog, progress, msg)
    return unless @stream
    begin
      @stream.puts(msg['text']) if msg['text']
    rescue StandardError => e
      $log.error('Failed to write output file: %s' % e)
      return false
    end
  end

  def end_dialog(dialog, progress)
    @stream.close if @stream
    @stream = nil
  end

end
