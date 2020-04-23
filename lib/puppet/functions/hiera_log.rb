
# The `consul_lookup` is a hiera 5 `data_hash` data provider function.
# See [the configuration guide documentation](https://puppet.com/docs/puppet/latest/hiera_config_yaml_5.html#configuring-a-hierarchy-level-built-in-backends) for
# how to use this function.
require 'logger'

Puppet::Functions.create_function(:hiera_log) do
  dispatch :hiera_log do
    param 'Variant[String, Numeric]', :key
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end


  def hiera_log(key, options, context)
    log_key(key, options)
    context.not_found
    return nil

  end

  def log_key(key, options)
    logdir = '/var/log/puppetlabs'
    size = 1024000
    filename = "hiera.log"
    retention = 4
    tag = ''
    if options.key?('tag')
      tag = options['tag']
    end
    if options.key?('logdir')
      logdir = options['logdir']
    end
    if options.key?('filename')
      filename = options['filename']
    end
    if options.key?('size')
      size = options['size']
    end
    if options.key?('retention')
      retention = options['retention']
    end
    location = logdir + "/" + filename
    logger = Logger.new(location, retention, size)
    logger.info(tag + key)

  end
  # def lookup_supported_params
  #   [
  #       :logdir,
  #       :size,
  #       :retention,
  #       :tag
  #   ]
  # end

end