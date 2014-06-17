# Burrow Output Plugin
# @author Tim Gunter <tim@vanillaforums.com>
#
# This plugin allows to extract a single key from an existing event and re-parse it with a given
# format, and then re-emit a new event with the key's value replaced, or with the whole record replaced.
#

class Fluent::BurrowPlugin < Fluent::Output
  # Register type
  Fluent::Plugin.register_output('burrow', self)

  # Required
  config_param :key_name, :string
  config_param :format, :string

  # Optional - tag format
  config_param :tag, :string, :default => nil                 # Create a new tag for the re-emitted event
  config_param :remove_prefix, :string, :default => nil       # Remove a prefix from the existing tag
  config_param :add_prefix, :string, :default => nil          # Add a prefix to the existing tag

  # Optional - record format
  config_param :action, :string, :default => 'inplace'        # The action to take once key parsing is complete
  config_param :keep_key, :bool, :default => false            # Keep original source key (only valid with 'overlay' and 'replace' actions)

  # Optional - time format
  config_param :keep_time, :bool, :default => false           # Keep the original event's "time" key
  config_param :record_time_key, :string, :default => 'time'  # Allow a custom time field in the record
  config_param :time_key, :string, :default => 'time'         # Allow a custom time field in the sub-record
  config_param :time_format, :string, :default => nil         # Allow a custom time format for the new record

  # Parse config hash
  def configure(conf)
    super

    # One of 'tag', 'remove_prefix' or 'add_prefix' must be specified
    if not @tag and not @remove_prefix and not @add_prefix
      raise Fluent::ConfigError, "One of 'tag', 'remove_prefix' or 'add_prefix' must be specified"
    end
    if @tag and (@remove_prefix or @add_prefix)
      raise Fluent::ConfigError, "Specifying both 'tag' and either 'remove_prefix' or 'add_prefix' is not supported"
    end

    # Prepare for tag modification if required
    if @remove_prefix
      @removed_prefix_string = @remove_prefix.chomp('.') + '.'
      @removed_length = @removed_prefix_string.length
    end
    if @add_prefix
      @added_prefix_string = @add_prefix.chomp('.') + '.'
    end

    # Validate action
    actions = ['replace','overlay','inplace']
    if not actions.include? @action
      raise Fluent::ConfigError, "Invalid 'action', must be one of #{actions.join(',')}"
    end

    # Validate action-based restrictions
    if @action == 'inplace' and @keep_key
      raise Fluent::ConfigError, "Specifying 'keep_key' with action 'inplace' is not supported"
    end

    # Prepare fluent's built-in parser
    @parser = Fluent::TextParser.new()
    @parser.configure(conf)
  end

  # This method is called when starting.
  def start
    super
  end

  # This method is called when shutting down.
  def shutdown
  end

  # This method is called when an event reaches Fluentd.
  def emit(tag, es, chain)

    # Figure out new event tag (either manually specified, or modified with add_prefix|remove_prefix)
    if @tag
      tag = @tag
    else
      if @remove_prefix and
          ( (tag.start_with?(@removed_prefix_string) and tag.length > @removed_length) or tag == @remove_prefix)
        tag = tag[@removed_length..-1]
      end
      if @add_prefix
        if tag and tag.length > 0
          tag = @added_prefix_string + tag
        else
          tag = @add_prefix
        end
      end
    end

    # Handle all currently available events in stream
    es.each do |time,record|
      # Extract raw key value
      raw_value = record[@key_name]

      # Remember original time key, or raw event time
      raw_time = record[@record_time_key]

      # Try to parse it according to 'format'
      t,values = raw_value ? @parser.parse(raw_value) : [nil, nil]

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
      end

      if ['overlay','replace'].include? @action
        if not @keep_key
          record.delete(@key_name)
        end
      end

      if @overlay
        # First delete source key for new record?


        # Then overlay
        r = record.merge(r)
      end

      # Preserve 'time' key?
      if @keep_time
        r[@record_time_key] = raw_time
      end

      # Emit event back to Fluent
      if r
        Fluent::Engine.emit(tag, t, r)
      end
    end

    chain.next
  end

end