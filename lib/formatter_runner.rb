require 'json'
require_relative '../formatters/lib/formatter_base'
require_relative 'util'

Dir[File.dirname(__FILE__) + '/../formatters/*.rb'].each do |file|
  require File.expand_path(file)
end

class FormatterRunner

  def initialize(dumper, progress)
    # We could potentially support more dumper types in the future, but for now,
    # this is the only possible option, so we can just assert on it
    unless dumper.get_output_type == 'json_lines'
      raise "FormatterRunner: unsupported dumper #{dumper.get_output_type}"
    end

    @progress = progress
  end

  def format(dialogs)
    return if dialogs.empty?
    formatters = self.class.load_formatters
    formatters.reject! do |formatter|
      formatter.start_backup(dialogs) == false
    end
    dialogs.each do |dialog|
      dialog_progress = @progress[dialog['id'].to_s]
      next unless dialog_progress
      formatters.reject! do |formatter|
        formatter.start_dialog(dialog, dialog_progress) == false
      end
      dumper_outfile = dialog_progress.dumper_state['outfile']
      json_file = File.join(get_backup_dir, dumper_outfile)
      File.open(json_file, 'r:UTF-8').each do |line|
        formatters.reject! do |formatter|
          msg = JSON.parse(line)
          formatter.format_message(dialog, dialog_progress, msg) == false
        end
      end
      formatters.reject! do |formatter|
        formatter.end_dialog(dialog, dialog_progress) == false
      end
    end
    formatters.each do |formatter|
      formatter.end_backup(dialogs)
    end
  end

private

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
