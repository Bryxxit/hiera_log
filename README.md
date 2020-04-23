# hiera_log

Hiera log is a custom backend that will log your looked up keys in a log file. This way you can see which keys are still relevant in your system etc. And by result you could possibly remove keys that are not relevant to your system anymore. You could also use it as a debug tool to see if your code looks up the relevant keys I guess.


## Usage
Minimal
```
hierarchy:
  - name: "Hiera log keys"
    lookup_key: hiera_log
```

By default it will write its log to /var/log/puppetlabs/hiera.log

If you get permission errors in your code you might have to create the file.

https://til.hashrocket.com/posts/cm5jxalutq-log-rotation-in-ruby
By default a retention of 4 is set and a max size of 1024000 or 4 times 1MB of logging

You can overwrite these settings in the options part of hiera
e.g.
```
hierarchy:
  - name: "Hiera log keys"
    lookup_key: hiera_log
    options:
      logdir: '/var/log/puppetlabs/hiera'
      filename: "%{::environment}-%{::trusted.certname}.log"
      tag: "%{::environment} - %{::trusted.certname} - "
```
options
 - logdir
 - filename
 - size
 - retention
 - tag

As you can see you can also supply a tag this will appear in your logs so you can further determine which node, etc. uses which lookups.

Example of log entries
I, [2019-10-28T13:24:21.977945 #24618]  INFO -- : key::key2
