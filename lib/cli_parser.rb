require 'optparse'

Options = Struct.new(:cfgfile, :kill_tg, :userdir, :backlog_limit)

class CliParser
  def self.parse(options)
    args = Options.new

    opt_parser = OptionParser.new do |opts|
      opts.banner = 'Usage: telegram-history-dump.rb [options]'

      opts.on('-cCFG', '--config=cfg.yaml', String,
              'Path to YAML configuration file') do |cfgfile|
        args.cfgfile = cfgfile
      end

      opts.on('-k', '--kill-tg', 'Kill telegram-cli after backup') do |kill_tg|
        args.kill_tg = kill_tg
      end

      opts.on('-h', '--help', 'Show help') do
        puts opts
        exit
      end

      opts.on('-dDIR', '--dir=DIR', String,
              'Subdirectory for output files',
              '(relative to backup_dir in YAML config)') do |userdir|
        args.userdir = userdir
      end

      opts.on('-lLIMIT', '--limit=LIMIT', Integer,
              'Maximum number of messages to backup',
              'for each target (overrides YAML config)') do |backlog_limit|
        args.backlog_limit = backlog_limit
      end

    end

    opt_parser.parse!(options)
    return args
  end
end
