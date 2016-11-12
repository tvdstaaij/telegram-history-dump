require 'date'
require 'fileutils'
require_relative 'formatter_base'

class DailyFileFormatter < FormatterBase

  def start_backup(dialogs)
    FileUtils.remove_dir(output_dir, true)
    FileUtils.mkdir_p(output_dir)
  end

  def format_dialog(dialog, messages)
    prev_date = nil
    output_stream = nil
    safe_name = get_safe_name(dialog['print_name'])
    @dialog_dir = File.join(output_dir, safe_name)
    FileUtils.mkdir_p(@dialog_dir)

    @messages = messages
    start_dialog(dialog)
    (0...messages.length).reverse_each do |i|
      message = messages[@msg_index = i]
      date = message['date']
      next unless date
      date = Time.at(date).to_date
      unless output_stream && date == prev_date
        output_stream.close if output_stream
        filename = get_filename_for_date(dialog, date)
        path = File.join(@dialog_dir, filename)
        begin
          output_stream = File.open(path, 'w:UTF-8')
        rescue StandardError => e
          $log.error('Failed to open output file: %s' % e)
          return
        end
      end
      format_message(dialog, message, output_stream)
      prev_date = date
    end
    end_dialog(dialog)
  end

  def start_dialog(dialog)
    nil
  end

  def end_dialog(dialog)
    nil
  end

  def format_message(dialog, message, output_stream)
    raise 'format_message must be implemented'
  end

  def get_filename_for_date(dialog, date)
    raise 'get_filename_for_date must be implemented'
  end

  def find_earlier_message(id)
    (@msg_index...@messages.length).each do |i|
      return @messages[i] if @messages[i]['id'] == id
    end
    nil
  end

end
