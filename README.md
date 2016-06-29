# telegram-history-dump

This utility is the successor of [telegram-json-backup][1], written from the
ground up in Ruby. It can create backups of your Telegram user and (super)group
dialogs using telegram-cli's remote control feature.
 
Compared to the old project, telegram-history-dump:

* Has better support for media downloads
* Supports output formats other than JSON and is extensible with custom formats
* Supports incremental backup (only new messages are downloaded)
* Does not depend on unstable Python/Lua bindings within telegram-cli
* Has a separate YAML formatted configuration file

The default configuration will backup all dialogs to a directory named `output`,
in JSON format, without downloading any media.

## Usage

### First time setup

1. Compile [telegram-cli][3], start it once to link your Telegram account
2. Make sure Ruby 2+ is installed on your system: `ruby --version`
3. Optionally configure your backup routine by editing `config.yaml`

### Performing a backup

1. Start telegram-cli with at least the following options:
   `telegram-cli --json -P 9009`
2. While telegram-cli is running, execute the script:
   `ruby telegram-history-dump.rb`

## Formatters

History will always be stored in [JSON Lines][5] compliant files. However,
additional output formats can be produced by uncommenting a few lines in the
configuration file.

You can enable one or more of the following formatter modules:

`html` creates styled, paginated chat logs vieweable with a web browser.

`plaintext` creates human-readable text files, organized as one file per day. 

`bare` outputs only the actual message texts without any context. It is meant
for linguistic / statistical analysis.

`pisg` creates daily logs compatible with the EnergyMech IRC logging format as
input for the [PISG][7] chat statistics generator. Also see [telegram-pisg][2].

You can also implement a custom formatter; see
`formatters/lib/formatter_base.rb` for details.

## Command line options

Most of the backup configuration is done through the config file, but a few
specific options are available as CLI options. None of them are mandatory.

```text
Usage: telegram-history-dump.rb [options]
    -c, --config=cfg.yaml            Path to YAML configuration file
    -k, --kill-tg                    Kill telegram-cli after backup
    -h, --help                       Show help
    -d, --dir=DIR                    Subdirectory for output files
                                     (relative to backup_dir in YAML config)
    -l, --limit=LIMIT                Maximum number of messages to backup
                                     for each target (overrides YAML config)
```

## Notes

Usage notes:

* It is possible to run telegram-cli on a different machine, e.g. as a daemon
  on a server. In this case you must pass `--accept-any-tcp` to telegram-cli and
  firewall the port appropriately to prevent unwanted exposure. Keep in mind
  that some options regarding media files will not work in a remote setup.
* Be careful with decreasing `chunk_delay` or increasing `chunk_size`. Telegram
  seems to rate limit history requests. Going too fast may cause an operation
  to time out and force the script to skip part of a dump.

Telegram-cli issues known to affect telegram-history-dump:

* [vysheng/tg#947][9] can cause crashes when dumping channels with more than 100
  messages.
* [vysheng/tg#904][10] can cause crashes when dialogs contain certain media
  files. If you get this, recompile telegram-cli with the suggested workaround. 

[1]: https://github.com/tvdstaaij/telegram-json-backup
[2]: https://github.com/tvdstaaij/telegram-pisg
[3]: https://github.com/vysheng/tg
[4]: http://bundler.io/
[5]: http://jsonlines.org/
[7]: http://pisg.sourceforge.net/
[9]: https://github.com/vysheng/tg/issues/947
[10]: https://github.com/vysheng/tg/issues/904
