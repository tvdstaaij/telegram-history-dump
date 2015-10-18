# telegram-history-dump

This utility is the successor of [telegram-json-backup][1], written from the
ground up in Ruby. It can create backups of your Telegram conversations using
telegram-cli's remote control feature.
 
Compared to the old project, telegram-history-dump:

* Has better support for media downloads
* Supports output formats other than JSON and is extensible with custom dumpers
* Does not depend on unstable Python/Lua bindings within telegram-cli
* Has a separate [JSON5][2] formatted configuration file

The default configuration will backup all dialogs to a directory named `output`,
in JSON format, without downloading any media.

## Setup

1. Compile [telegram-cli][3], start it once to link your Telegram account
2. Make sure Ruby 2+ is installed on your system: `ruby --version`
3. Install gem dependencies with [Bundler][4], or manually with `gem`:

  ```bash
  gem install json5
  ```

## Usage

1. Configure your backup routine by editing `config.json5`
2. Start telegram-cli with at least the following options:
   `telegram-cli --json -P 9009`
3. Run the backup: `ruby telegram-history-dump.rb`

## Dumpers

You can select one of the following dumper modules in the configuration file.

`json` creates [JSON Lines][5] compliant files with one event object per line,
ordered from newest to oldest. 

`plaintext` creates human-readable logs, organized as one file per day. 

`bare` outputs only the actual message texts without any context. It is meant
for linguistic / statistical analysis.

You can also implement a custom dumper; see `dumpers/dumper_interface.rb` for
details.

## Notes

* It is possible to run telegram-cli on a different machine, e.g. as a daemon
  on a server. In this case you must pass `--accept-any-tcp` to telegram=cli and
  firewall the port appropriately to prevent unwanted exposure. Keep in mind
  that some options regarding media files will not work in a remote setup.
* Be careful with decreasing `chunk_delay` or increasing `chunk_size`. Telegram
  seems to rate limit history requests and going too fast may cause an operation
  to time out and force the script to skip part of a dump.

[1]: https://github.com/tvdstaaij/telegram-json-backup
[2]: http://json5.org/
[3]: https://github.com/vysheng/tg
[4]: http://bundler.io/
[5]: http://jsonlines.org/
