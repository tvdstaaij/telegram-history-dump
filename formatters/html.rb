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
      if dialog['type'] != 'user'
        dialog_rendering = '<span class="icon img-group"></span>'
      else
        dialog_rendering = '<span class="icon img-single-user"></span>'
      end
      dialog_list_html += "<div class='dialog msg %s'>#{dialog_rendering} <a href='#{safe_name}-0.html'>%s</a></div>" % [('out' if dialog['type'] == 'user'), CGI::escapeHTML(dialog['print_name'])]
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
    file = File.open(current_filename, 'w:UTF-8')
    file.puts(@html_template_header % [CGI::escapeHTML(dialog['print_name']), dialog_title])

    message_count = 0
    page_count = 0
    messages.reverse_each do |msg|
      if msg['text']
        if not msg['out'] and dialog['type'] != 'user'
          author = '<div class=author>%s:</div>'% msg['from']['print_name']
        else
          author = ''
        end

        date = Time.at(msg['date'])
		if $config['formatters']['html']['use_utc_time']
		  date = "#{date.utc} UTC"
		end

        file.puts("<div class='msg %s' title='#{date}'>#{author} %s</div>" % [(msg['out'] ? 'out' : 'in'), CGI::escapeHTML(msg['text'])])
      else
        # TODO: media
      end

	  message_count += 1
	  if message_count > $config['formatters']['html']['paginate']
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
		file.puts(@html_template_footer % navigation)
		file.close()

		# Open a new file and write the header again
		file = File.open(current_filename, 'w:UTF-8')
		file.puts(@html_template_header % [CGI::escapeHTML(dialog['print_name']), dialog_title + (' - page %i' % (page_count + 1) if page_count > 0)])
	  end
    end
    file.puts(@html_template_footer % '')
	file.close()
  end

end

