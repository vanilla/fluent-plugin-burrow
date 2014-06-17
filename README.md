fluent-plugin-burrow
====================

This plugin for [Fluentd](http://fluentd.org) allows to extract a single key from an existing event and re-parse it with
a supplied format. A new event is then emitted, with the record modified by the now-decoded key's value.

## Motivation

out_burrow is designed to allow post-facto re-parsing of nested key elements.

For example, lets say your source application writes to syslog, but instead of plain string messages, it writes JSON
encoded data. /var/log/syslog contains the following entry:

    Jun 17 21:16:22 app1 5012162: {"event":"csrf_failure","msg":"Invalid transient key for System.","username":"System","userid":"1","ip":"192.34.93.74","method":"GET","domain":"http://timgunter.ca","path":"/dashboard/settings","tags":["csrf","failure"],"accountid":5009392,"siteid":5012162}

In td-agent.conf, you might have something like this to read this event:

```
<source>
    type syslog
    port 5140
    bind 127.0.0.1
    tag raw.app.vanilla.events
</source>
```

Unfortunately, in_syslog does not understand that the `message` field is encoded with JSON, so it escapes all the data
and makes it unusable down the line. If we piped these events to a file, we would see something like this:

```
2014-06-17T21:16:22Z	raw.app.vanilla.events.local0.err	{"host":"app1","ident":"5012162","message":"{\"event\":\"csrf_failure\",\"msg\":\"Invalid transient key for System.\",\"username\":\"System\",\"userid\":\"1\",\"ip\":\"192.34.93.74\",\"method\":\"GET\",\"domain\":\"http://timgunter.ca\",\"path\":\"/dashboard/authentication\",\"tags\":[\"csrf\",\"failure\"],\"accountid\":5009392,\"siteid\":5012162}"}
```

Note how the `message` field has been escaped. This means that when this event eventually makes its way to a file, or
another system (like elasticsearch for example), it will not be ready for consumption. That's where `out_burrow` comes in.

Adding the following `match` block to td-agent.conf allows us to intercept the raw syslog events and re-parse the
message field as JSON:

```
<match raw.app.vanilla.events.**>
    type burrow
    key_name message
    action inplace
    remove_prefix raw
    format json
</match>
```

There are several components to this rule, but for now lets look at the output:

```
2014-06-17T21:16:23Z	app.vanilla.events.local0.err	{"host":"app1","ident":"5012162","message":{"event":"csrf_failure","msg":"Invalid transient key for System.","username":"System","userid":"1","ip":"192.34.93.74","method":"GET","domain":"http://timgunter.ca","path":"/dashboard/settings/mobilethemes","tags":["csrf","failure"],"accountid":5009392,"siteid":5012162}}
```

Now the JSON is no longer escaped, and can be easily parsed by both fluentd and elasticsearch.

## Settings

### key_name

`required`

This is the name of the key we want to examine and re-parse, and is required.

### format

`required`

This is format that Fluentd should expect the `key_name` field to be encoded with. out_burrow supports the same built-in
format as Fluent::TextParser (and in_tail):

- apache
- apache2
- nginx
- syslog
- json
- csv
- tsv
- ltsv

### tag
optional

When this even is re-emitted, change its tag to this setting's value.

### remove_prefix

`optional`

When this event is re-emitted, remove this prefix from the source tag and use the resulting string as the new event's
tag. This setting automatically adds a trailing period `.` to its value before stripping.

### add_prefix

`optional`

When this event is re-emitted, prepend this prefix to the source tag and use the resulting string as the new event's tag.
This setting automatically adds a trailing period `.` to its value before prepending.

#### One of the 'tag', 'remove_prefix', or 'add_prefix' settings is required. 'remove_prefix' and 'add_prefix' can
co-exist together.

### action

`optional` and defaults to `inplace`

The value of this setting determines how the new event will be constructed. There are three distinct options here:

- inplace

Perform decoding 'in place'. When the `key_name` field is successfully parsed, its contents will be written back to its
original key in the original record, which will then be re-emitted.

- overlay

Overlay decoded data on top of original record, and re-emit. In our example above, if 'overlay' was used instead of
'inplace', the resulting record would have been:

```
{
    "host":"app1",
    "ident":"5012162",
    "event":"csrf_failure",
    "msg":"Invalid transient key for System.",
    "username":"System",
    "userid":"1",
    "ip":"192.34.93.74",
    "method":"GET",
    "domain":"http://timgunter.ca",
    "path":"/dashboard/settings",
    "tags":["csrf","failure"],
    "accountid":5009392,
    "siteid":5012162
}
```

- replace

Replace the original entirely with the contents of the decoded field. In our example above, if 'replace' was used
instead of 'inplace', the resulting record would have been:

```
{
    "event":"csrf_failure",
    "msg":"Invalid transient key for System.",
    "username":"System",
    "userid":"1",
    "ip":"192.34.93.74",
    "method":"GET",
    "domain":"http://timgunter.ca",
    "path":"/dashboard/settings",
    "tags":["csrf","failure"],
    "accountid":5009392,
    "siteid":5012162
}
```

### keep_key

`optional` and defaults to `false`

Keep original source key (only valid with 'overlay' and 'replace' actions). When this is `true`, the original encoded
source key is retained in the output.

### keep_time

`optional` and defaults to `false`

Keep the original record's "time" key. If the original top level record contains a

### record_time_key

`optional` and defaults to `time`

If `keep_time` is `true`, this field specifies the key that contains the original records's time. The value of this key
will be copied into the new record after it has been parsed.

### time_key

`optional` and defaults to `time`

When the `key_name` field's value is being parsed, look for this key and interpret it as the record's `time` key.

### time_format

`optional` and defaults to nil

When parsing the `key_name` field's value and if `time_key` is set, this field denotes the format to expect the `time`
to be in.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

If you have a question, [open an Issue](https://github.com/vanilla/fluent-plugin-burrow/issues).