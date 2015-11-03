#!/usr/bin/env ruby

require 'fileutils'
require 'json'
require 'socket'
require 'logger'
require 'timeout'

# Load gems while interpreter warnings are disabled
$VERBOSE = false
require 'json5'
$VERBOSE = true

require_relative 'lib/util'
require_relative 'lib/cli_parser'

cli_opts = CliParser.parse(ARGV)

def connect_socket
  return if defined?($sock) && $sock
  $log.info('Attaching to telegram-cli control socket at %s:%d' %
              [$config['tg_host'], $config['tg_port']])
  $sock = TCPSocket.open($config['tg_host'], $config['tg_port'])
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
  $dumper.start_dialog(dialog)
  filter_regex = $config['filter_regex'] && eval($config['filter_regex'])
  offset = 0
  keep_dumping = true
  while keep_dumping do
    $log.info('Dumping "%s" (range %d-%d)' % [
                dialog['print_name'],
                offset + 1,
                offset + $config['chunk_size']
              ])
    msg_chunk = nil
    Timeout::timeout($config['chunk_timeout']) do
      msg_chunk = exec_tg_command('history', dialog['print_name'],
                                  $config['chunk_size'], offset)
    end
    raise 'Expected array' unless msg_chunk.is_a?(Array)
    msg_chunk.reverse_each do |msg|
      $log.warn('Message without date: %s' % msg) unless msg['date']
      unless msg['text'] && filter_regex && filter_regex =~ msg['text']
        process_media(dialog, msg)
        $dumper.dump_msg(dialog, msg)
      end
      offset += 1
      if $config['backlog_limit'] > 0 && offset >= $config['backlog_limit']
        keep_dumping = false
        break
      end
    end
    keep_dumping = false if msg_chunk.length < $config['chunk_size']
    sleep($config['chunk_delay']) if keep_dumping
  end
  $dumper.end_dialog(dialog)
end

def process_media(dialog, msg)
  return unless msg.include?('media')
  %w(document video photo audio).each do |media_type|
    next unless $config['download_media'][media_type]
    next unless msg['media']['type'] == media_type
    response = nil
    Timeout::timeout($config['media_timeout']) do
      begin
        response = exec_tg_command('load_' + media_type, msg['id'])
      rescue StandardError => e
        $log.error('Failed to download media file: %s' % e)
        return
      end
    end
    filename = case
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
    msg['media']['file'] = filename if filename
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
  candidates = case dialog['type']
    when 'user' then $config['backup_users']
    when 'chat' then $config['backup_groups']
    when 'channel' then $config['backup_channels']
    else return false
  end
  return false unless candidates
  return true if candidates.empty?
  candidates.each do |candidate|
    next unless candidate
    dialog_name = get_safe_name(dialog['print_name']).upcase
    candidate_name = get_safe_name(candidate).upcase
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

$config = JSON5.parse(
    File.read(
        cli_opts.cfgfile ||
        File.expand_path('../config.json5', __FILE__)
    )
)
$log = Logger.new(STDOUT)

FileUtils.mkdir_p(get_backup_dir)

$log.info('Loading dumper module \'%s\'' % $config['dumper'])
require_relative 'dumpers/%s/dumper.rb' % $config['dumper']
$dumper = Dumper.new
connect_socket

dialogs = exec_tg_command('dialog_list')
channels = $config['backup_channels'] ?
  exec_tg_command('channel_list') : []
raise 'Expected array' unless dialogs.is_a?(Array) && channels.is_a?(Array)
dialogs = dialogs.concat(channels)
raise 'No dialogs found' if dialogs.empty?
backup_list = []
skip_list = []
dialogs.each do |dialog|
  next if dialog['print_name'].nil?
  next if dialog['print_name'].empty?
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
  rescue Timeout::Error
    $log.error('Command timeout, skipping to next dialog')
    disconnect_socket
  end
end

$dumper.end_backup
if cli_opts.kill_tg
  connect_socket
  $sock.puts('quit')
end
$log.info('Finished')
