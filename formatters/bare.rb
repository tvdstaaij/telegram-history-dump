require_relative 'lib/formatter_base'

class BareFormatter < FormatterBase

  NAME = 'bare'

  def start_backup(dialogs)
    FileUtils.remove_dir(output_dir, true)
    FileUtils.mkdir_p(output_dir)
  end

  def format_dialog(dialog, messages)
    safe_name = get_safe_name(dialog['print_name'])
    output_file = File.join(output_dir, safe_name + '.txt')
    begin
      File.open(output_file, 'w:UTF-8') do |stream|
        messages.reverse_each do |msg|
          stream.puts(msg['text']) if msg['text']
        end
      end
    rescue StandardError => e
      $log.error('Failed to write output file: %s' % e)
    end
  end

end
