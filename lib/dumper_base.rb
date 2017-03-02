require_relative 'util'

class DumperBase

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

  # Will be called for each chunk of messages (from newest to oldest)
  # See the python binding documentation to get an idea of the msg attributes:
  # https://github.com/vysheng/tg/blob/master/README-PY.md#attributes-1
  # Returning boolean false causes an early abort (skips to the next dialog)
  def dump_chunk(dialog, messages)
    # dialog: Hash, messages: Array of Hash
    raise 'dump_chunk must be implemented'
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
