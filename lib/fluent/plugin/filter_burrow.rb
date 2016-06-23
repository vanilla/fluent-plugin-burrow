# Burrow Filter Plugin
# @author Tim Gunter <tim@vanillaforums.com>
#
# This plugin allows to extract a single key from an existing event and re-parse it with a given
# format, and then re-emit a new event with the key's value replaced, or with the whole record replaced.
#

require 'fluent/filter'

module Fluent
class BurrowFilter < Filter
  # Register type
  Fluent::Plugin.register_filter('burrow', self)

  # Required
  config_param :key_name, :string
  config_param :format, :string

  # Optional - record format
  config_param :action, :string, :default => 'inplace'        # The action to take once key parsing is complete
  config_param :keep_key, :bool, :default => false            # Keep original source key (only valid with 'overlay' and 'replace' actions)

  # Optional - time format
  config_param :keep_time, :bool, :default => false           # Keep the original event's "time" key
  config_param :record_time_key, :string, :default => 'time'  # Allow a custom time field in the record
  config_param :time_key, :string, :default => 'time'         # Allow a custom time field in the sub-record
  config_param :time_format, :string, :default => nil         # Allow a custom time format for the new record


  def configure(conf)
    super

    # Validate action
    actions = ['replace','overlay','inplace','prefix']
    if not actions.include? @action
      raise Fluent::ConfigError, "Invalid 'action', must be one of #{actions.join(',')}"
    end

    # Validate action-based restrictions
    if @action == 'inplace' and @keep_key
      raise Fluent::ConfigError, "Specifying 'keep_key' with action 'inplace' is not supported"
    end
    if @action == 'prefix' and not @data_prefix
      raise Fluent::ConfigError, "You must specify 'data_prefix' with action 'prefix'"
    end

    # Prepare fluent's built-in parser
    @parser = Fluent::Plugin.new_parser(@format)
    @parser.configure(conf) if @parser.respond_to?(:configure)
  end


  def start
    super
  end


  def shutdown
    super
  end


  def filter(tag, time, record)

    # Extract raw key value
    raw_value = record[@key_name]

    # Remember original time key, or raw event time
    raw_time = record[@record_time_key]

    # Try to parse it according to 'format'
    t      = nil
    values = nil

    if raw_value
      @parser.parse(raw_value) {|_t, _v| t = _t, values = _v}
    end

    # Set new event's time to current time unless new time key was found in the sub-event
    t ||= raw_time

    r = values;

    # Overlay new record on top of original record?
    case @action
    when 'inplace'
      r = record.merge({@key_name => r})
    when 'overlay'
      r = record.merge(r)
    when 'replace'
      # noop
    when 'prefix'
      r = record.merge({@data_prefix => r})
    end

    # Keep the key?
    if ['overlay','replace','prefix'].include? @action
      if not @keep_key and not r.nil? and r.has_key?(@key_name)
        r.delete(@key_name)
      end
    end

    # Preserve 'time' key?
    if @keep_time
      r[@record_time_key] = raw_time
    end

    r
  end

end
end
