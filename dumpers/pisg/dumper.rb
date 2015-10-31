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
      user_names[user_id] = name.capitalize unless name == ''
    end
    deduplicate_names(user_names)

    path = File.join(@output_dir, 'usermap.cfg')
    File.open(path, 'w') do |stream|
      user_names.each do |user_id, name|
        stream.puts('<user nick="%s" alias="u%d">' % [name, user_id])
      end
    end
  end

  def dump_msg(dialog, msg)
    super
    return unless msg['date'] and msg['from']
    return if msg['from']['print_name'].to_s == ''
    @users[msg['from']['id']] = msg['from']
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
    'Telegram_%s_%s.log' % [
      get_safe_name(dialog['print_name']),
      date.strftime('%Y%m%d')
    ]
  end

  def deduplicate_names(name_map)
    names = name_map.values
    dupes = names.select{|v| names.count(v) > 1 }.uniq
    dupes.each do |dupe|
      dupe_map = name_map.select{|_, v| v === dupe }

      # Primary strategy: add initial letter of surname
      surname_dedup = Hash[
        dupe_map.keys.zip(
          dupe_map.map do |user_id, name|
            last_name = @users[user_id]['last_name']
            next name if last_name.to_s.empty?
            name + last_name[0].upcase
          end
        )
      ]
      next name_map.update(surname_dedup) unless has_dupes?(surname_dedup)

      # Secondary strategy: counter suffix
      suffix_num = 0
      number_dedup = Hash[
        dupe_map.keys.zip(
          dupe_map.map do |_, name|
            suffix_num += 1
            suffix_num < 2 ? name : name + suffix_num.to_s
          end
        )
      ]
      next name_map.update(number_dedup) unless has_dupes?(number_dedup)

      # Desperate fallback strategy: ID suffix
      dupe_map.update(dupe_map){|user_id, name| name + user_id.to_s }
      name_map.update(dupe_map)
    end
  end

end

def has_dupes?(collection)
  values = collection.respond_to?('values') ? collection.values : collection
  values != values.uniq
end

Dumper = PisgDumper
