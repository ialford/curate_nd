CurateNd::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true
  config.eager_load = false

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true
  config.action_dispatch.show_exceptions = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_files = false

  # Compress JavaScripts and CSS
  config.assets.compress = true

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Defaults to nil and saved in location specified by config.assets.prefix
  # config.assets.manifest = YOUR_PATH

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # See everything in the log (default is :info)
  # config.log_level = :debug

  # Prepend all log lines with the following tags
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  config.assets.precompile += %w( modernizr.js rich_text_editor.js simplemde.min.css )

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  config.application_root_url = "https://curatesvrpprd.library.nd.edu"

  # for iiif image viewer
  config.manifest_viewer = "https://viewer-iiif.library.nd.edu/universalviewer/index.html#?manifest="
  config.manifest_builder_url = "https://presentation-iiif.library.nd.edu/"

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  # config.active_record.auto_explain_threshold_in_seconds = 0.5

  config.fits_path = '/opt/fits/current/fits.sh'

  begin
    # Why the explicit require? Because the headless workers of pre-production
    # are not explicitly requiring clamav; This is because the web application
    # portion of pre-production doesn't know about clamav. Instead of mixing
    # environments, we are going to let the workers fail.
    require 'clamav'
    ClamAV.instance.loaddb
    Curate.configuration.default_antivirus_instance = lambda {|file_path|
      ClamAV.instance.scanfile(file_path)
    }
  rescue LoadError => e
    logger.error("#{e.class}: #{e}")
  end

  config.use_proxy_for_download.enable

  config.logstash = [
    {
      type: :file,
      path: "log/#{Rails.env}.log"
    }
  ]

  config.log_level = :info
end
