require 'optparse'

Options = Struct.new(:cfgfile, :kill_tg, :userdir, :backlog_limit)

class CliParser
  def self.parse(options)
    args = Options.new()

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: telegram-history-dump.rb [options]"

      opts.on("-c", "--config=cfgfile.yaml",
              "Path to configuration file") do |str|
        args.cfgfile = str
      end

      opts.on("-k", "--kill-tg", "Kill telegram-cli after backup") do |bool|
        args.kill_tg = bool
      end

      opts.on("-h", "--help", "Show help") do
        puts opts
        exit
      end

      opts.on("-dDIR", "--dir=DIR", String, "Subdirectory for logs") do |userdir|
        args.userdir = userdir
      end

      opts.on("-lLIMIT", "--limit=LIMIT", Integer, "Maximum number of messages to backup for each target (0 means unlimited)") do |backlog_limit|
        args.backlog_limit = backlog_limit
      end

    end

    opt_parser.parse!(options)
    return args
  end
end


