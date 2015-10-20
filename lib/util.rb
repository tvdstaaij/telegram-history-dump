def get_safe_name(dialog_name)
  dialog_name.gsub(/([\/\\<>:"|?*]|[^\u0021-\uFFFF])/,
                   $config['character_substitute'])
end

def get_full_name(user)
  return '' if !user || user['first_name'].to_s == ''
  name = user['first_name']
  if $config['display_last_name'] && user['last_name'].to_s != ''
    name += ' %s' % user['last_name']
  end
  name
end

def get_backup_dir
  File.expand_path(File.join('..', '..', $config['backup_dir']), __FILE__)
end

def get_media_dir(dialog)
  File.join(get_backup_dir, get_safe_name(dialog['print_name']) + '_files')
end
