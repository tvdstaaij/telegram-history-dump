require 'json'
require_relative '../formatters/lib/formatter_base'
require_relative 'json_lines_dump_reader'
require_relative 'util'

Dir[File.dirname(__FILE__) + '/../formatters/*.rb'].each do |file|
  require File.expand_path(file)
end

class FormatterRunner
  WINDOW_SIZE = 100 # At most WINDOW_SIZE*2 messages are kept in cache

  def initialize(dumper, progress)
    @dumper = dumper
    @progress = progress
  end

  def format(dialogs)
    return if dialogs.empty?
    formatters = self.class.load_formatters

    formatters.reject! do |formatter|
      formatter.start_backup(dialogs) == false
    end

    dialogs.each do |dialog|
      window = []
      next_msg_index = 0
      dialog_progress = @progress[dialog['id'].to_s]

      next unless dialog_progress
      formatters.reject! do |formatter|
        formatter.start_dialog(dialog, dialog_progress) == false
      end

      dump_reader = create_dump_reader(dialog_progress)
      dump_reader.start
      loop do
        new_msg = dump_reader.read_msg
        window.push(new_msg) if new_msg
        if !new_msg || window.length >= WINDOW_SIZE*2
          window[next_msg_index..-1].each do |msg|
            self.class.add_reply_data(msg, window)
            formatters.reject! do |formatter|
              formatter.format_message(dialog, dialog_progress, msg) == false
            end
          end
          window.slice!(0, WINDOW_SIZE)
          next_msg_index = window.length
        end
        break unless new_msg
      end
      dump_reader.end

      formatters.reject! do |formatter|
        formatter.end_dialog(dialog, dialog_progress) == false
      end
    end

    formatters.each do |formatter|
      formatter.end_backup(dialogs)
    end
  end

private

  def create_dump_reader(dialog_progress)
    case @dumper.get_output_type
      when 'json_lines'
        dumper_outfile = dialog_progress.dumper_state['outfile']
        filename = File.join(get_backup_dir, dumper_outfile)
        JsonLinesDumpReader.new(filename)
      else
        raise "FormatterRunner: unsupported dumper #{@dumper.get_output_type}"
    end
  end

  def self.add_reply_data(msg, window)
    return unless msg['reply_id']
    window.each do |cached_msg|
      case cached_msg['id']
        when msg['id'] then break
        when msg['reply_id']
          msg['reply_msg'] = cached_msg
          break
      end
    end
  end

  def self.load_formatters
    formatter_classes = {}
    FormatterBase.descendants.each do |formatter_class|
      unless formatter_class::NAME.empty?
        formatter_classes[formatter_class::NAME] = formatter_class
      end
    end
    ($config['formatters'] || {}).map do |name,options|
      unless formatter_classes.key?(name)
        raise 'Formatter "%s" is enabled but does not exist' % [name]
      end
      formatter_classes[name].new(options || {})
    end
  end

end
