require_relative '../daily_file_dumper'

class PisgDumper < DailyFileDumper

  def start_dialog(dialog)
    super
    @users = {}
  end

  def end_dialog(dialog)
    super

    user_names = {}
    @users.each do |user_id, user|
      name = get_safe_name(get_full_name(user))
      user_names[user_id] = name unless name == ''
    end

    path = File.join(@output_dir, 'usermap.cfg')
    File.open(path, 'w') do |stream|
      user_names.each do |user_id, name|
        is_duplicate = user_names.values.select{|v| v == name}.length > 1
        unique_name = is_duplicate ? name + user_id.to_s : name
        stream.puts('<user nick="%s" alias="u%d">' % [unique_name, user_id])
      end
    end
  end

  def dump_msg(dialog, msg)
    super
    return unless msg['date']
    @users[msg['from']['id']] = msg['from'] if msg['from']
    lines = msg['text'].to_s.split("\n")
    lines.push('') if lines.empty?
    lines.reverse_each do |msg_line|
      dump_msg_line(dialog, msg, msg_line)
    end
  end

  def dump_msg_line(dialog, msg, msg_line)
    date_str = Time.at(msg['date']).strftime('[%H:%M:%S] ')
    user_ref = 'u' + msg['from']['id'].to_s

    line = case msg['event'].downcase
      when 'message'
        if !msg['fwd_from'] && msg_line != ''
          "<#{user_ref}> #{msg_line}"
        else nil end
      when 'service'
        target_ref = msg['action']['user'] ?
          'u' + msg['action']['user']['id'].to_s : ''
        case msg['action']['type'].downcase
          when 'chat_add_user'
            "*** Joins: #{user_ref} (tg@#{user_ref}.users.telegram)"
          when 'chat_del_user'
            if target_ref == user_ref
              "*** Parts: #{user_ref} (tg@#{user_ref}.users.telegram)"
            else
              "*** #{target_ref} was kicked by #{user_ref} (Removed from group)"
            end
          when 'chat_rename'
            "*** #{user_ref} changes topic to '#{msg['action']['title']}'"
          else nil
        end
      else nil
    end

    @output_buf.push(date_str + line) if line
  end

  def get_filename_for_date(dialog, date)
    prefix = (dialog['type'].upcase == 'CHAT') ? '#' : ''
    'Telegram_%s%s_%s.log' % [
      prefix,
      get_safe_name(dialog['print_name']),
      date.strftime('%Y%m%d')
    ]
  end

end

Dumper = PisgDumper
