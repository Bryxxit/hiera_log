# The `hiera_log` is a hiera 5 `data_hash` data provider function.
# See [the configuration guide documentation](https://puppet.com/docs/puppet/latest/hiera_config_yaml_5.html#configuring-a-hierarchy-level-built-in-backends) for
# how to use this function.
require 'logger'
require 'net/http'
require 'uri'
require 'base64'
require 'tempfile'

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
    # Default values
    mode = options.fetch('mode', 'file')  # Default to file mode
    logdir = '/var/log/puppetlabs'
    size = 1024000
    filename = "hiera.log"
    retention = 4
    tag = ''
    
    # Common options
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
    
    log_message = tag + " " + key
    
    case mode
    when 'file'
      log_to_file(logdir, filename, size, retention, log_message)
    when 'nexus'
      log_to_nexus_with_rotation(options, log_message)
    else
      raise "Invalid mode '#{mode}'. Supported modes are 'file' and 'nexus'."
    end
  end
  
  def log_to_file(logdir, filename, size, retention, message)
    location = logdir + "/" + filename
    logger = Logger.new(location, retention, size)
    logger.info(message)
  end
  
  def log_to_nexus_with_rotation(options, message)
    # Required Nexus options
    nexus_url = options['nexus_url']
    nexus_directory = options['nexus_directory']
    
    if nexus_url.nil? || nexus_directory.nil?
      raise "Nexus mode requires 'nexus_url' and 'nexus_directory' options"
    end
    
    # Authentication options
    username = options['nexus_username']
    password = options['nexus_password']
    password_file = options['nexus_password_file']
    
    # Read password from file if password_file is provided
    if password_file && !password
      begin
        password = File.read(password_file).strip
      rescue => e
        raise "Failed to read password from file '#{password_file}': #{e.message}"
      end
    end
    
    # Log configuration (same as file mode)
    logdir = options.fetch('temp_log_dir', '/tmp/hiera_nexus_logs')
    filename = options['filename'] || 'hiera_nexus.log'
    size = options.fetch('size', 1024000)
    retention = options.fetch('retention', 4)
    
    # Ensure log directory exists
    Dir.mkdir(logdir) unless Dir.exist?(logdir)
    
    # Log to local file first (this handles rotation automatically)
    location = logdir + "/" + filename
    logger = Logger.new(location, retention, size)
    logger.info(message)
    
    # Upload any rotated log files that haven't been uploaded yet
    upload_rotated_logs(logdir, filename, nexus_url, nexus_directory, username, password, options)
  end
  
  def upload_rotated_logs(logdir, base_filename, nexus_url, nexus_directory, username, password, options = {})
    # Find all log files (current and rotated ones)
    log_pattern = File.join(logdir, "#{base_filename}*")
    
    Dir.glob(log_pattern).each do |log_file|
      next if log_file.end_with?('.uploaded') # Skip marker files
      
      marker_file = "#{log_file}.uploaded"
      
      # Skip if already uploaded
      next if File.exist?(marker_file)
      
      # Skip current log file (still being written to) - only upload rotated ones
      if log_file == File.join(logdir, base_filename)
        # Check if file is "old enough" or large enough to upload
        file_age_minutes = (Time.now - File.mtime(log_file)) / 60
        file_size = File.size(log_file)
        min_age = options.fetch('min_age_minutes', 5)
        min_size = options.fetch('min_size_bytes', 1000)
        
        next unless file_age_minutes >= min_age || file_size >= min_size
      end
      
      begin
        upload_to_nexus(nexus_url, nexus_directory, log_file, username, password)
        # Mark as uploaded
        File.write(marker_file, "Uploaded at #{Time.now}")
      rescue => e
        Puppet.warning("Failed to upload log file #{log_file} to Nexus: #{e.message}")
      end
    end
  end
  
  def upload_to_nexus(nexus_url, directory, file_path, username, password)
    filename = File.basename(file_path)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    # Add timestamp to avoid conflicts
    remote_filename = "#{timestamp}_#{filename}"
    
    # Construct the full URL
    full_url = "#{nexus_url.chomp('/')}/#{directory.chomp('/')}/#{remote_filename}"
    uri = URI(full_url)
    
    # Read file content
    file_content = File.read(file_path)
    
    # Create HTTP request
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    
    request = Net::HTTP::Put.new(uri)
    request.body = file_content
    request['Content-Type'] = 'text/plain'
    
    # Add authentication if provided
    if username && password
      request.basic_auth(username, password)
    end
    
    # Send request
    response = http.request(request)
    
    unless response.code.start_with?('2')
      raise "Failed to upload to Nexus: #{response.code} #{response.message}"
    end
  end
  
  # def lookup_supported_params
  #   [
  #       :mode,                    # 'file' or 'nexus' (default: 'file')
  #       :logdir,                  # Directory for file mode
  #       :size,                    # Log file size for file mode
  #       :retention,               # Number of files to retain for file mode
  #       :tag,                     # Tag to prepend to log messages
  #       :filename,                # Log filename for file mode
  #       :nexus_url,               # Nexus repository URL (required for nexus mode)
  #       :nexus_directory,         # Directory in Nexus to upload to (required for nexus mode)
  #       :nexus_username,          # Username for Nexus authentication (optional)
  #       :nexus_password,          # Password for Nexus authentication (optional)
  #       :nexus_password_file,     # File containing password for Nexus authentication (optional)
  #       :temp_log_dir,            # Directory for nexus temp logs (default: '/tmp/hiera_nexus_logs')
  #       :min_age_minutes,         # Min age before uploading current log (default: 5)
  #       :min_size_bytes           # Min size before uploading current log (default: 1000)
  #   ]
  # end
end
