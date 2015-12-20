require 'optparse'

Options = Struct.new(:cfgfile, :kill_tg)

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
    end

    opt_parser.parse!(options)
    return args
  end
end


