require_relative '../../lib/util'

# To create a new custom formatter (example for format 'useful'):
# * Create file 'formatters/useful.rb'
# * Require this file (require_relative 'lib/formatter_base')
# * Declare a class named UsefulFormatter inheriting from FormatterBase
# * Inside the class, override the name: NAME = 'useful'
# * Implement format_dialog and optionally the start/end methods
# * Add an entry for the formatter in config.yaml so it can be enabled

class FormatterBase

  # The methods/properties below are intended to be overridden, although only
  # NAME and format_message are mandatory
  #
  # Notes:
  # * Arguments are passed by reference and MUST NOT be modified
  # * If something goes horribly wrong, log an error and return false to abort

  # Canonical name of the formatter, should match the filename and class name
  # Will be used to determine the output directory (output/formatted/<name>)
  NAME = ''

  # Will be called before formatting the first dialog
  def start_backup(dialogs)
    # dialogs: Array of Hash
    nil
  end

  # Will be called before the first format_message call of a dialog
  def start_dialog(dialog, progress)
    # dialog: Hash, progress: DumpProgress
    nil
  end

  # Will be called once for every message in a dialog,
  # between the start_dialog and end_dialog calls
  # dialog and progress arguments are the same as in start_dialog
  # See tg python binding documentation to get an idea of the msg attributes:
  # https://github.com/vysheng/tg/blob/master/README-PY.md#attributes-1
  def format_message(dialog, progress, msg)
    # dialog: Hash, progress: DumpProgress, msg: Hash
    raise 'format_message must be implemented'
  end

  # Will be called after the last format_message call of a dialog
  # dialog and progress arguments are the same as in start_dialog
  def end_dialog(dialog, progress)
    # dialog: Hash, progress: DumpProgress
    nil
  end

  # Will be called after formatting the last dialog
  def end_backup(dialogs)
    # dialogs: Array of Hash
    nil
  end

  # End of overridable methods/properties

  # Instance variable @options will contain the formatter option hash from
  # the configuration file, or an empty hash if there are no options
  def initialize(options)
    @options = options
  end

  # Class method descendants will give every formatter that implements this base
  @@formatters = []
  def self.descendants
    @@formatters
  end

  protected

  # If the formatter outputs files (likely), this gives the directory where they
  # should go. Using this directory is not mandatory, but if it is used, the
  # formatter is responsible for ensuring it exists.
  def output_dir
    File.join(get_backup_dir, 'formatted', self.class::NAME)
  end

  private

  # Mechanism to automatically detect which formatters are implemented
  def self.inherited(child_class)
    @@formatters.push(child_class)
  end

end
