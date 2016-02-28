require_relative 'lib/daily_file_formatter'

class PlaintextFormatter < DailyFileFormatter

  NAME = 'plaintext'

  def format_message(dialog, message, output_stream)
    date_str = Time.at(message['date']).strftime('[%s] ' % @options['date_format'])
    from_name = get_full_name(message['from'])

    line = case message['event'].downcase
      when 'message'
        fwd_from_name = get_full_name(message['fwd_from'])
        if !fwd_from_name.empty?
          from_name += ' (forwarded from %s)' % fwd_from_name
        elsif message['reply_id']
          from_name += ' (reply)'
          # Possible impovement: find reply text
        end

        content = case
          when message['text'].to_s != ''
            message['text']
          when message['media']
            filename = message['media']['file']
            media_ref = filename ? ': %s' % filename : ''
            "#{message['media']['type']}#{media_ref}"
            # Possible improvement: include more media-specific information
          else nil
        end

        case
          when content.nil?
            nil
          when dialog['type'] == 'channel'
            content
          when message['text'].to_s != ''
            "#{from_name}: #{content}"
          when message['media']
            "#{from_name} sent #{content}"
          else nil
        end

      when 'service'
        user_name = get_full_name(message['action']['user'])
        case message['action']['type'].downcase
          when 'chat_add_user'
            "#{from_name} added #{user_name}"
          when 'chat_del_user'
            "#{from_name} removed #{user_name}"
          when 'chat_rename'
            "#{from_name} changed group name to #{message['action']['title']}"
          else nil
        end
      else nil
    end

    output_stream.puts(date_str + line + "\n") if line
  end

  def get_filename_for_date(dialog, date)
    '%s_%s.log' % [
      get_safe_name(dialog['print_name']),
      date.strftime('%Y-%m-%d')
    ]
  end

end
