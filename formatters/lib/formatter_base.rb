require_relative '../../lib/util'

# To create a new custom formatter (example for format 'useful'):
# * Create file 'formatters/useful.rb'
# * Require this file (require_relative 'lib/formatter_base')
# * Declare a class named UsefulFormatter inheriting from FormatterBase
# * Inside the class, override the name: NAME = 'useful'
# * Implement format_dialog and optionally start_backup/end_backup
# * Add an entry for the formatter in config.yaml so it can be enabled

class FormatterBase

  # The methods/properties below are intended to be overridden, although only
  # NAME and format_dialog are mandatory

  # Canonical name of the formatter, should match the filename and class name
  # Will be used to determine the output directory (output/formatted/<name>)
  NAME = ''

  # Will be called before formatting the first dialog
  # Can be used for initialization
  def start_backup(dialogs)
    # dialogs: Array of Hash
    nil
  end

  # Called once for every downloaded dialog
  # Message array is in reverse chronological order
  def format_dialog(dialog, messages)
    # dialog: Hash, messages: Array of Hash
    raise 'format_dialog must be implemented'
  end

  # Will be called after formatting the last dialog
  # Can be used for cleanup
  def end_backup
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
