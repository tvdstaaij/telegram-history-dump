require 'date'
require 'fileutils'
require_relative 'dumper_interface'

class DailyFileDumper < DumperInterface

  def start_dialog(dialog, progress)
    @state = progress.dumper_state ? progress.dumper_state.clone : {}
    @prev_date = nil
    @last_outfile = nil
    @output_buf = []
    safe_name = get_safe_name(dialog['print_name'])
    @output_dir = File.join(get_backup_dir, safe_name)
    FileUtils.mkdir_p(@output_dir)
    if @state['last_outfile']
      @backup_file = @state['last_outfile'] + '.bak'
      FileUtils.mv(@state['last_outfile'], @backup_file)
    end
  end

  def dump_msg(dialog, msg)
    date = msg['date']
    return false unless date
    date = Time.at(date).to_date
    flush(dialog) if date != @prev_date && !@output_buf.empty?
    @prev_date = date
    true
  end

  def msg_fresh?(msg, progress)
    return true if !progress.last_date || !msg['date']
    msg_date = Time.at(msg['date']).to_date
    last_date = Time.at(progress.last_date).to_date
    msg_date >= last_date
  end

  def flush(dialog)
    return if @output_buf.empty? || @prev_date.nil?
    filename = get_filename_for_date(dialog, @prev_date)
    path = File.join(@output_dir, filename)
    @last_outfile ||= path
    File.open(path, 'w') do |stream|
      @output_buf.reverse_each do |line| stream.puts(line) end
    end
    @output_buf.clear
  end

  def end_dialog(dialog)
    flush(dialog)
    @state['last_outfile'] = @last_outfile if @last_outfile
    File.delete(@backup_file) if @backup_file
    @state
  end

  def get_filename_for_date(dialog, date)
    raise 'get_filename_for_date must be implemented'
  end

end
