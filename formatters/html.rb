require_relative 'lib/formatter_base'
require 'cgi' # For HTML encoding

class HtmlFormatter < FormatterBase

  NAME = 'html'

  def start_backup(dialogs)
    FileUtils.remove_dir(output_dir, true)
    FileUtils.mkdir_p(output_dir)
    FileUtils.cp('formatters/html-data/telegram-history-dump.css', output_dir)

    @html_template_index = File.read('formatters/html-data/index.template')
    @html_template_header = File.read('formatters/html-data/dialog-header.template')
    @html_template_footer = File.read('formatters/html-data/dialog-footer.template')

    dialog_list_html = ''
    dialogs.each do |dialog|
      safe_name = get_safe_name(dialog['print_name'])
	  html_safe_name = CGI::escapeHTML(safe_name)
      if dialog['type'] != 'user'
        dialog_rendering = '<span class="icon img-group"></span>'
      else
        dialog_rendering = '<span class="icon img-single-user"></span>'
      end
      dialog_list_html += "<div class='dialog msg %s'>#{dialog_rendering} <a href='#{html_safe_name}-0.html'>%s</a></div>" % [('out' if dialog['type'] == 'user'), CGI::escapeHTML(dialog['print_name'])]
    end
    index_file = File.join(output_dir, 'index.html')
    File.open(index_file, 'w:UTF-8') do |stream|
      stream.puts(@html_template_index % dialog_list_html)
    end
  end

  def format_dialog(dialog, messages)
    if dialog['type'] != 'user'
      dialog_title = 'Group chat: %s' % CGI::escapeHTML(dialog['print_name'])
    else
      dialog_title = 'Chat with %s' % CGI::escapeHTML(dialog['print_name'])
    end
    safe_name = get_safe_name(dialog['print_name'])
    current_filename = File.join(output_dir, safe_name + '-0.html')
    backup_file = File.open(current_filename, 'w:UTF-8')
    backup_file.puts(@html_template_header % [CGI::escapeHTML(dialog['print_name']), dialog_title])

    message_count = 0
    page_count = 0
    messages.reverse_each do |msg|
      if not msg['out'] and dialog['type'] != 'user'
        # If this is an incoming message in a group chat, display the author
        author = '<div class=author>%s:</div>'% msg['from']['print_name']
      else
        author = ''
      end

      date = Time.at(msg['date'])
      if $config['formatters']['html']['use_utc_time']
        date = "#{date.utc} UTC"
      end

      if msg['text']
        backup_file.puts("<div class='msg %s' title='#{date}'>#{author} %s</div>" % [(msg['out'] ? 'out' : 'in'), CGI::escapeHTML(msg['text'])])
      elsif msg['media'] and msg['media']['file'] # TODO: handle other media types, e.g. webpage
        relative_path = File.join("../../media", safe_name, File.basename(msg['media']['file']))
        extension = File.extname(msg['media']['file'])
        if msg['media']['type'] == 'photo' or ['png', 'jpg', 'gif', 'svg', 'jpeg', 'bmp', 'webp'].include? extension[1..-1]
          # Note: webp is almost certainly a sticker; special support for those is to do (although the need is
          # questionable as they are inlined already).
          file = "<a target='_blank' href='#{relative_path}'><img src='#{relative_path}'></a>"
          if msg['media']['caption']
            file += '<br>' + msg['media']['caption']
          end
        else
          if msg['media']['type'] == 'audio' or ['mp3', 'wav', 'ogg'].include? extension[1..-1]
            filetype = 'audio'
          elsif msg['media']['type'] == 'video' or ['mp4', 'mov', '3gp', 'avi', 'webm'].include? extension[1..-1]
            filetype = 'video'
          else
            # documents
            file = "<a href='#{relative_path}'>Download %s file</a>" % extension
          end
          if filetype == 'audio' or filetype == 'video'
            file = "<#{filetype} src='#{relative_path}' controls>Your browser does not support inline playback.</#{filetype}><br><a href='#{relative_path}'>Download #{filetype}</a>"
          end
        end

        # Regardless of file type, write this :)
        backup_file.puts("<div class='msg %s' title='#{date}'>#{author}<br>#{file}</div>" % [(msg['out'] ? 'out' : 'in')])
      end

      message_count += 1
      messages_per_page = $config['formatters']['html']['paginate']
      if messages_per_page and messages_per_page > 0 and message_count > messages_per_page
        # We reached our message limit on this page; paginate!
        # Is there a previous page? If yes, link to it.
        navigation = ''
        if page_count > 0
          navigation += '<a class=prevpage href="%s">Previous page</a>' % current_filename
        end

        page_count += 1
        message_count = 0

        # Link to the next page and end the file
        current_filename = File.join(output_dir, "#{safe_name}-%s.html" % page_count)
        navigation += '<a class=nextpage href="%s">Next page</a>' % current_filename
        backup_file.puts(@html_template_footer % navigation)
        backup_file.close()

        # Open a new file and write the header again
        backup_file = File.open(current_filename, 'w:UTF-8')
        backup_file.puts(@html_template_header % [CGI::escapeHTML(dialog['print_name']), dialog_title + (' - page %i' % (page_count + 1) if page_count > 0)])
      end
    end
    backup_file.puts(@html_template_footer % '')
    backup_file.close()
  end

  def end_backup
    $log.info("HTML export finished, see: output/formatted/html/index.html")
  end

end

