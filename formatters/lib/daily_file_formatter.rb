require 'date'
require 'fileutils'
require_relative 'formatter_base'

class DailyFileFormatter < FormatterBase

  def start_backup(dialogs)
    FileUtils.remove_dir(output_dir, true)
    FileUtils.mkdir_p(output_dir)
  end

  # Must call `super` if overridden
  def start_dialog(dialog, progress)
    @prev_date = nil
    @stream = nil
    safe_name = get_safe_name(dialog['print_name'])
    @dialog_dir = File.join(output_dir, safe_name)
    FileUtils.mkdir_p(@dialog_dir)
  end

  def format_message(dialog, progress, message)
    date = message['date']
    return unless date
    date = Time.at(date).to_date
    unless @stream && date == @prev_date
      @stream.close if @stream
      filename = get_filename_for_date(dialog, date)
      path = File.join(@dialog_dir, filename)
      begin
        @stream = File.open(path, 'w:UTF-8')
      rescue StandardError => e
        $log.error('Failed to open output file: %s' % e)
        return false
      end
    end
    begin
      format_message_to_stream(dialog, message, @stream)
    rescue StandardError => e
      $log.error('Failed to format message: %s' % e)
      return false
    end
    @prev_date = date
  end

  # Must call `super` if overridden
  def end_dialog(dialog, progress)
    @stream.close if @stream
    @stream = nil
  end

  def format_message_to_stream(dialog, message, stream)
    raise 'format_message_to_stream must be implemented'
  end

  def get_filename_for_date(dialog, date)
    raise 'get_filename_for_date must be implemented'
  end

end
