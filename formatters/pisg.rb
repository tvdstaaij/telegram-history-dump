require 'time'
require_relative 'lib/daily_file_formatter'

class PisgFormatter < DailyFileFormatter

  NAME = 'pisg'

  def start_dialog(dialog)
    @users = {}
    @oldest_message_date = nil
  end

  def end_dialog(dialog)
    user_names = {}
    @users.each do |user_id, user|
      name = get_safe_name(get_full_name(user))
      user_names[user_id] = name.capitalize unless name == ''
    end
    deduplicate_names(user_names)

    path = File.join(@dialog_dir, 'usermap.cfg')
    File.open(path, 'w:UTF-8') do |stream|
      user_names.each do |user_id, name|
        stream.puts('<user nick="%s" alias="u%s">' % [name, user_id.to_s])
      end
    end

    if dialog['title']
      path = File.join(@dialog_dir, 'chat_title')
      File.open(path, 'w:UTF-8') {|f| f.write(dialog['title']) }
    end
    if @oldest_message_date
      path = File.join(@dialog_dir, 'oldest_message_date')
      File.open(path, 'w:UTF-8') do |f|
        f.write(@oldest_message_date.utc.iso8601)
      end
    end
  end

  def format_message(dialog, message, output_stream)
    involved_users = []
    involved_users << message['from'] if message['from']
    if message['to'] && message['to']['peer_type'] == 'user'
      involved_users << message['to']
    end
    if message['action'] && message['action']['user']
      involved_users << message['action']['user']
    end
    involved_users.each do |user|
      @users[user['peer_id']] = user if user['peer_id']
    end

    return unless message['date'] and message['from']
    return if message['from']['print_name'].to_s == ''
    @oldest_message_date ||= Time.at(message['date'])
    lines = message['text'].to_s.split("\n")
    lines.push('') if lines.empty?
    lines.reverse_each do |message_line|
      dump_message_line(message, message_line, output_stream)
    end
  end

  def dump_message_line(message, message_line, output_stream)
    date_str = Time.at(message['date']).strftime('[%H:%M:%S] ')
    user_ref = 'u' + message['from']['peer_id'].to_s

    line = case message['event'].downcase
      when 'message'
        if !message['fwd_from'] && message_line != ''
          "<#{user_ref}> #{message_line}"
        else nil end
      when 'service'
        target = message['action']['user']
        target_ref = target ? 'u' + target['peer_id'].to_s : ''
        case message['action']['type'].downcase
          when 'chat_add_user'
            "*** Joins: #{target_ref} (tg@#{target_ref}.users.telegram)"
          when 'chat_add_user_link'
            "*** Joins: #{user_ref} (tg@#{user_ref}.users.telegram)"
          when 'chat_del_user'
            return if target['print_name'].to_s == ''
            if target_ref == user_ref
              "*** Parts: #{user_ref} (tg@#{user_ref}.users.telegram)"
            else
              "*** #{target_ref} was kicked by #{user_ref} (Removed from group)"
            end
          when 'chat_rename'
            "*** #{user_ref} changes topic to '#{message['action']['title']}'"
          else nil
        end
      else nil
    end

    output_stream.puts(date_str + line) if line
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
            name + last_name.split(' ').last[0].upcase
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
