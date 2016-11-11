require_relative 'util'

class MsgId
  include Comparable

  attr_reader :raw_hex

  def initialize(raw_hex)
    @raw_hex = raw_hex
  end

  def sequence_hex
    @sequence_hex ||= decode_sequence
  end

  def <=>(other)
    sequence_hex <=> other.sequence_hex
  end

  def to_s
    @raw_hex
  end

  private

  def assert_length
    unless [48,64].include?(@raw_hex.length)
      raise 'Unexpected message ID length (%d). Please report this as an '\
            'issue if your telegram-cli is up to date.' % [@raw_hex.length]
    end
  end

  # This function extracts a sortable hex string from the full ID
  # The following assumptions are made about the telegram-cli build:
  # * `sizeof(long long)` equals 8
  # * Little endian byte order
  def decode_sequence
    assert_length
    sequence_hex_le = @raw_hex[-32,16]
    flip_bytes(sequence_hex_le)
  end

end
