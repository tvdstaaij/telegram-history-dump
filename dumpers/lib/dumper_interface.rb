require_relative '../../lib/util'

# To implement a dumper:
# * Create a .rb file named after the dumper in 'dumpers'
# * Require this file: require_relative 'lib/dumper_interface'
# * Declare a class SomeDumper, inheriting from DumperInterface
# * Implement one or more of the functions listed below (at least dump_msg)

# Note:
#   Dumpers are a low-level construct and as of v2.0.0 they are no longer used
#   for implementing custom output formats. Instead, custom formatters have been
#   introduced for this purpose (see /formatters/lib/formatter_base.rb).

class DumperInterface

  # Will be called before backing up the first dialog
  # Can be used for initialization
  def start_backup
    nil
  end

  # Will be called just before dumping a dialog's messages
  def start_dialog(dialog, progress)
    # dialog: Hash, progress: DumpProgress
    nil
  end

  # Will be called before each message to dump, to determine whether it is new
  # enough to back up
  # This default makes sense in simple cases, override for advanced custom logic
  def msg_fresh?(msg, progress)
    # msg: Hash, progress: DumpProgress
    return false if msg['id'].to_s.empty?
    !progress.newest_id || MsgId.new(msg['id']) > progress.newest_id
  end

  # Will be called for each message to dump (from newest to oldest)
  # See the python binding documentation to get an idea of the msg attributes:
  # https://github.com/vysheng/tg/blob/master/README-PY.md#attributes-1
  # Returning boolean false causes an early abort (skips to the next dialog)
  def dump_msg(dialog, msg)
    # dialog, msg: Hash
    raise 'dump_msg must be implemented'
  end

  # Will be called just after dumping a dialog's messages
  # Optionally return a hash with state information that will be saved as
  # custom progress data
  # dialog: Hash
  def end_dialog(dialog)
    # dialog: Hash
    nil
  end

  # Will be called after backing up the last dialog
  # Can be used for cleanup
  def end_backup
    nil
  end

  # Should return a string that uniquely identifies this dumper type
  # This is used as a subdirectory name in the output directory
  def get_output_type
    'unnamed_dump_type'
  end

end
