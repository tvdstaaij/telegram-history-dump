require 'json'

class DumpProgress

  attr_reader :last_id
  attr_reader :last_date
  attr_reader :dumper_state
  attr_writer :dumper_state

  def initialize(last_id = nil, last_date = nil, dumper_state = {})
    @last_id = last_id
    @last_date = last_date
    @dumper_state = dumper_state
  end

  def self.from_hash(hash)
    self.new(hash['last_id'], hash['last_date'], hash['dumper_state'])
  end

  def to_hash
    {
      :last_id => @last_id,
      :last_date => @last_date,
      :dumper_state => @dumper_state
    }
  end

  def to_json(*a)
    to_hash.to_json(*a)
  end

  def bump_id(id)
    @last_id = id if !@last_id || id > @last_id
  end

  def bump_date(date)
    @last_date = date if !@last_date || date > @last_date
  end

end
