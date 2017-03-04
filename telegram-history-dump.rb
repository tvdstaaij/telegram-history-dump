#!/usr/bin/env ruby

require 'fileutils'
require 'json'
require 'logger'
require 'socket'
require 'time'
require 'timeout'
require 'yaml'
require_relative 'dumpers/json'
require_relative 'formatters/lib/formatter_base'
require_relative 'lib/cli_parser'
require_relative 'lib/dump_progress'
require_relative 'lib/util'
require_relative 'lib/tg_def'
require_relative 'lib/msg_id'

Dir[File.dirname(__FILE__) + '/formatters/*.rb'].each do |file|
  require File.expand_path(file)
end

cli_opts = CliParser.parse(ARGV)

def connect_socket
  return if defined?($sock) && $sock

  if $config['tg_sock']
    $log.info('Attaching to telegram-cli control socket at %s' % [
      $config['tg_sock']
    ])
    $sock = UNIXSocket.new($config['tg_sock'])
  else
    $log.info('Attaching to telegram-cli control socket at %s:%d' % [
      $config['tg_host'], $config['tg_port']
    ])
    $sock = TCPSocket.open($config['tg_host'], $config['tg_port'])
  end
end

def disconnect_socket
  $sock.close if defined?($sock) && $sock
  $sock = nil
end

def exec_tg_command(command, *arguments)
  $sock.puts [command].concat(arguments).join(' ')
  $sock.gets # Skip the response code (undocumented gibberish)
  json = JSON.parse($sock.gets) # Read the response object
  $sock.gets # Skip the terminating newline
  if json.is_a?(Hash) && json['result'] == 'FAIL'
    raise 'Telegram command <%s> failed: %s' % [command, json]
  end
  json
end

def dump_dialog(dialog)
  if $config['download_media'].values.any? && $config['copy_media']
    FileUtils.mkdir_p(get_media_dir(dialog))
  end
  id_str = dialog['id'].to_s
  old_progress = $progress_snapshot[id_str] || DumpProgress.new
  cur_progress = ($progress[id_str] ||= DumpProgress.new)
  $dumper.start_dialog(dialog, old_progress)
  filter_regex = $config['filter_regex'] && eval($config['filter_regex'])
  prev_msg_id = nil
  offset = 0
  keep_dumping = true
  while keep_dumping do
    cur_offset = offset
    $log.info('Dumping "%s" (range %d-%d)' % [
                dialog['print_name'],
                cur_offset + 1,
                cur_offset + $config['chunk_size']
              ])
    msg_chunk = nil
    retry_count = 0
    last_chunk_download_time = Time.now
    loop do
      if retry_count >= $config['chunk_retry']
        $log.error('Failed to fetch chunk of %d messages from offset %d '\
                   'after retrying %d times. Dump of "%s" is incomplete.' % [
                     $config['chunk_size'], cur_offset,
                     retry_count, dialog['print_name']
                   ])
        msg_chunk = []
        offset += $config['chunk_size']
        break
      end
      last_chunk_download_time = Time.now
      begin
        Timeout::timeout($config['chunk_timeout']) do
          msg_chunk = exec_tg_command('history', dialog['print_name'],
                                      $config['chunk_size'], cur_offset)
        end
        if msg_chunk.is_a?(Array)
          break
        end
        $log.warn('telegram-cli returned a non array chunk, retrying... (%d/%d)' % [
          retry_count += 1, $config['chunk_retry']
        ])
      rescue Timeout::Error
        $log.warn('Timeout, retrying... (%d/%d)' % [
          retry_count += 1, $config['chunk_retry']
        ])
      end
    end
    raise 'Expected array' unless msg_chunk.is_a?(Array)

    msg_chunk.reverse_each do |msg|
      dump_msg = true
      if msg['id'].to_s.empty?
        $log.warn('Dropping message without id: %s' % msg)
        dump_msg = false
        msg_id = nil
      else
        msg_id = MsgId.new(msg['id'])
      end
      if msg_id && prev_msg_id && msg_id >= prev_msg_id
        $log.warn('Message ids are not sequential (%s[%s] -> %s[%s])' % [
          prev_msg_id.raw_hex, prev_msg_id.sequence_hex,
          msg_id.raw_hex, msg_id.sequence_hex,
        ])
      end
      unless msg['date']
        $log.warn('Dropping message without date: %s' % msg)
        dump_msg = false
      end

      prev_msg_id = msg_id
      cur_progress.update(msg)

      if msg['text'] && filter_regex && filter_regex =~ msg['text']
        dump_msg = false
      end

      unless $dumper.msg_fresh?(msg, old_progress)
        if keep_dumping
          $log.info('Reached end of new messages since last backup')
        end
        dump_msg = false
        keep_dumping = false
      end

      if dump_msg
        process_media(dialog, msg)
        if $dumper.dump_msg(dialog, msg) == false
          keep_dumping = false
        end
      end

      offset += 1
      if $config['backlog_limit'] > 0 && offset >= $config['backlog_limit']
        keep_dumping = false
        break
      end
    end

    keep_dumping = false if offset < cur_offset + $config['chunk_size']
    if keep_dumping
      time_to_sleep = last_chunk_download_time - Time.now +
                      $config['chunk_delay']
      sleep(time_to_sleep) if time_to_sleep > 0
    end
  end
  state = $dumper.end_dialog(dialog) || {}
  cur_progress.dumper_state=(state)
end

def process_media(dialog, msg)
  return unless msg.include?('media')
  %w(document video photo audio).each do |media_type|
    next unless $config['download_media'][media_type]
    next unless msg['media']['type'] == media_type
    response = nil
    begin
      Timeout::timeout($config['media_timeout']) do
        response = exec_tg_command('load_' + media_type, msg['id'])
      end
    rescue StandardError => e
      # This is a warning because we're going to log an error afterwards
      $log.warn('Failed to download media file: %s' % e)
    end
    filename = case
      when response.nil? || !response.is_a?(Hash)
        $log.error('Wrong response on media download for message id %s' % msg['id'])
        nil
      when $config['copy_media']
        filename = File.basename(response['result'])
        destination = File.join(get_media_dir(dialog), fix_media_ext(filename))
        FileUtils.cp(response['result'], destination)
        destination
      else
        response['result']
    end
    begin
      File.delete(response['result']) if $config['delete_media']
    rescue StandardError => e
      $log.error('Failed to delete media file: %s' % e)
    end
    msg['media']['file'] = filename
  end
end

# telegram-cli saves media files with weird nonstandard extensions sometimes,
# so replace known cases of these with their canonical extensions
def fix_media_ext(filename)
  filename
    .sub(/\.mpga$/, '.mp3')
    .sub(/\.oga$/, '.ogg')
end

def backup_target?(dialog)
  dialog_type = case
    when dialog['type'] == 'channel' &&
         (dialog['flags'] & TgDef::TGLCHF_MEGAGROUP) != 0
      then 'supergroup'
    else dialog['type']
  end
  candidates = case dialog_type
    when 'user' then $config['backup_users']
    when 'chat' then $config['backup_groups']
    when 'channel' then $config['backup_channels']
    when 'supergroup' then $config['backup_supergroups']
    else
      $log.warn('Unknown type "%s" for dialog "%s"' % [
        dialog_type, dialog['print_name']
      ])
      return false
  end

  return false unless candidates
  return true if candidates.empty?
  candidates.each do |candidate|
    next unless candidate
    return true if candidate.to_s == dialog['id'].to_s
    next unless candidate.is_a?(String)
    dialog_name = strip_tg_special_chars(dialog['print_name'])
    dialog_name = get_safe_name(dialog_name).upcase
    candidate_name = strip_tg_special_chars(candidate)
    candidate_name = get_safe_name(candidate_name).upcase
    return true if dialog_name.include?(candidate_name)
  end
  false
end

def format_dialog_list(dialogs)
  return '(none)' if dialogs.empty?
  dialogs.map do |dialog|
    '"' + dialog['print_name'] + '"'
  end
    .join(', ')
end

def save_progress
  return unless $config['track_progress']
  progress_hash = {
    :dumper => $dumper.get_output_type,
    :last_modified => DateTime.now.new_offset(0).iso8601,
    :dialogs => $progress
  }
  progress_json = JSON.pretty_generate(progress_hash) + "\n"
  File.write($progress_file, progress_json)
end

$config = YAML.load_file(
  cli_opts.cfgfile ||
  File.expand_path('../config.yaml', __FILE__)
)
STDOUT.sync = true
$log = Logger.new(STDOUT)

if $config['track_progress'] && system_big_endian?
  raise 'For reasons you do not want to know, a little endian system is '\
        'necessary for incremental backups. Please report this as an issue.'
end

unless cli_opts.userdir.nil? || cli_opts.userdir.empty?
  $config['backup_dir'] = File.join($config['backup_dir'], cli_opts.userdir)
end

unless cli_opts.backlog_limit.nil? || cli_opts.backlog_limit < 0
  $config['backlog_limit'] = cli_opts.backlog_limit
end

FileUtils.mkdir_p(get_backup_dir)

$dumper = JsonDumper.new
$progress = {}
$progress_snapshot = {}
if $config['track_progress']
  $progress_file = File.join(get_backup_dir, 'progress.json')
  progress_json = File.exists?($progress_file) ?
    File.read($progress_file, :encoding => 'UTF-8') : '{}'
  progress_hash = JSON.parse(progress_json)
  if progress_hash['dumper'] &&
     progress_hash['dumper'] != $dumper.get_output_type
    raise 'Dumper conflict: using "%s" but progress file reads "%s". '\
      % [$dumper.get_output_type, progress_hash['dumper']]
  end
  (progress_hash['dialogs'] || {}).each do |k,v|
    $progress[k] = DumpProgress.from_hash(v)
    $progress_snapshot[k] = DumpProgress.from_hash(v)
  end
end

formatter_classes = {}
enabled_formatters = []
FormatterBase.descendants.each do |formatter_class|
  unless formatter_class::NAME.empty?
    formatter_classes[formatter_class::NAME] = formatter_class
  end
end
($config['formatters'] || {}).each do |name,options|
  unless formatter_classes.key?(name)
    raise 'Formatter "%s" is enabled but does not exist' % [name]
  end
  enabled_formatters.push(formatter_classes[name].new(options || {}))
end

connect_socket

dialogs = exec_tg_command('dialog_list', $config['maximum_dialogs'])
channels = exec_tg_command('channel_list', $config['maximum_dialogs'])
raise 'Expected array' unless dialogs.is_a?(Array) && channels.is_a?(Array)
dialogs = dialogs.concat(channels)
raise 'No dialogs found' if dialogs.empty?
backup_list = []
skip_list = []
dialogs.each do |dialog|

  # Supergroups may have more than one list entry because they are included in
  # both dialog_list and channel_list, so ignore duplicate IDs
  next if backup_list.any? do |selected_dialog|
    return false unless selected_dialog.include?('peer_id')
    selected_dialog['peer_id'] == dialog['peer_id']
  end

  # Compatibility with latest tg (1.4+)
  dialog['id'] = dialog['peer_id'] if dialog.key?('peer_id')
  dialog['type'] = dialog['peer_type'] if dialog.key?('peer_type')

  # Print name is empty for e.g. deleted users
  # Substitute an empty print name with something like 'user#123456'
  if dialog['print_name'].nil? || dialog['print_name'].empty?
    dialog['print_name'] = '%s#%s' % [dialog['type'], dialog['id'].to_s]
  end

  if backup_target?(dialog)
    backup_list.push(dialog)
  else
    skip_list.push(dialog)
  end
end

$log.info('Skipping %d dialogs: %s' % [
            skip_list.length, format_dialog_list(skip_list)
          ])
$log.info('Backing up %d dialogs: %s' % [
            backup_list.length, format_dialog_list(backup_list)
          ])

$dumper.start_backup
backup_list.each_with_index do |dialog,i|
  sleep($config['chunk_delay']) if i > 0
  begin
    connect_socket
    dump_dialog(dialog)
    save_progress
  rescue Timeout::Error
    $log.error('Unhandled timeout, skipping to next dialog')
    disconnect_socket
  end
end
$dumper.end_backup

unless enabled_formatters.empty?
  $log.info('Formatting messages')
  enabled_formatters.each do |formatter|
    formatter.start_backup(backup_list)
  end
  backup_list.each do |dialog|
    dumper_outfile = $progress[dialog['id'].to_s].dumper_state['outfile']
    json_file = File.join(get_backup_dir, dumper_outfile)
    messages = []
    File.open(json_file, 'r:UTF-8').each do |line|
      messages.push(JSON.parse(line))
    end
    enabled_formatters.each do |formatter|
      formatter.format_dialog(dialog, messages)
    end
  end
  enabled_formatters.each do |formatter|
    formatter.end_backup
  end
end

if cli_opts.kill_tg
  connect_socket
  $sock.puts('quit')
end
$log.info('Finished')
