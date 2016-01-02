require_relative '../daily_file_dumper'

class PlaintextDumper < DailyFileDumper

  def dump_msg(dialog, msg)
    return unless super
    date_str = Time.at(msg['date']).strftime('[%s] ' % $config['date_format'])
    from_name = get_full_name(msg['from'])

    line = case msg['event'].downcase
      when 'message'
        fwd_from_name = get_full_name(msg['fwd_from'])
        if !fwd_from_name.empty?
          from_name += ' (forwarded from %s)' % fwd_from_name
        elsif msg['reply_id']
          from_name += ' (reply)'
          # Unfortunately finding out who the user was replying to is nontrivial
        end

        content = case
          when msg['text'].to_s != ''
            msg['text']
          when msg['media']
            filename = msg['media']['file']
            media_ref = filename ? ': %s' % filename : ''
            "#{msg['media']['type']}#{media_ref}"
            # It would be possible to include more media-specific information
            # here, but I don't feel like it right now
          else nil
        end

        case
          when content.nil?
            nil
          when dialog['type'] == 'channel'
            content
          when msg['text'].to_s != ''
            "#{from_name}: #{content}"
          when msg['media']
            "#{from_name} sent #{content}"
          else nil
        end

      when 'service'
        user_name = get_full_name(msg['action']['user'])
        case msg['action']['type'].downcase
          when 'chat_add_user'
            "#{from_name} added #{user_name}"
          when 'chat_del_user'
            "#{from_name} removed #{user_name}"
          when 'chat_rename'
            "#{from_name} changed group name to #{msg['action']['title']}"
          else nil
        end
      else nil
    end

    @output_buf.push(date_str + line) if line
  end

  def get_filename_for_date(dialog, date)
    '%s_%s.log' % [
      get_safe_name(dialog['print_name']),
      date.strftime('%Y-%m-%d')
    ]
  end

end

Dumper = PlaintextDumper
