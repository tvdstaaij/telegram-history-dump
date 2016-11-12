require_relative 'lib/daily_file_formatter'

class PlaintextFormatter < DailyFileFormatter

  NAME = 'plaintext'

  def format_message(dialog, message, output_stream)
    date_str = Time.at(message['date']).strftime('[%s] ' % @options['date_format'])
    from_name = get_full_name(message['from'])
    from_name = '(Unknown)' if from_name.empty?

    line = case message['event'].downcase
      when 'message'
        fwd_from_name = get_full_name(message['fwd_from'])
        if !fwd_from_name.empty?
          from_name += ' (forwarded from %s)' % fwd_from_name
        elsif message['reply_id']
          reply_target = find_earlier_message(message['reply_id'])
          if reply_target
            reply_name = get_full_name(reply_target['from'])
            from_name += ' (in reply to %s)' %
              [reply_name.to_s.empty? ? 'someone' : reply_name]
          else
            from_name += ' (reply)'
          end
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
        user = message['action']['user']
        user_name = get_full_name(user)
        case message['action']['type'].downcase
          when 'chat_add_user'
            if message['from']['peer_id'] == user['peer_id'] ||
               !message['from']['peer_id']
              "#{user_name} joined"
            else
              "#{from_name} added #{user_name}"
            end
          when 'chat_add_user_link'
            "#{from_name} joined with an invite link"
          when 'chat_del_user'
            if message['from']['peer_id'] == user['peer_id'] ||
               !message['from']['peer_id']
              "#{user_name} left"
            else
              "#{from_name} removed #{user_name}"
            end
          when 'chat_rename'
            "#{from_name} changed group name to \"%s\"" %
              message['action']['title']
          when 'chat_change_photo'
            "#{from_name} changed group photo"
          when 'chat_created'
            "Group \"#{message['action']['title']}\" created"
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
