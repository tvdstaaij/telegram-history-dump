def get_safe_name(dialog_name)
  dialog_name.gsub(/[^\w\-.,;]/, '_')
end

def get_backup_dir
  File.expand_path(File.join('..', '..', $config['backup_dir']), __FILE__)
end

def get_media_dir(dialog)
  File.join(get_backup_dir, get_safe_name(dialog['print_name']) + '_files')
end
