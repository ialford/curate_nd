require 'orcid/configuration'
require 'orcid/exceptions'
require 'figaro'
require 'mappy'
require 'virtus'
require 'omniauth-orcid'
require 'email_validator'
require 'simple_form'

# The namespace for all things related to Orcid integration
module Orcid
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end
  end

  module_function
  def configure
    yield(configuration)
  end

  def mapper
    configuration.mapper
  end

  def provider
    configuration.provider
  end

  def parent_controller
    configuration.parent_controller
  end

  def authentication_model
    configuration.authentication_model
  end

  def connect_user_and_orcid_profile(user, orcid_profile_id)
    authentication_model.create!(
      provider: 'orcid', uid: orcid_profile_id, user: user
    )
  end

  def access_token_for(orcid_profile_id, collaborators = {})
    client = collaborators.fetch(:client) { oauth_client }
    tokenizer = collaborators.fetch(:tokenizer) { authentication_model }
    tokenizer.to_access_token(
      uid: orcid_profile_id, provider: 'orcid', client: client
    )
  end

  # Returns true if the person with the given ORCID has already obtained an
  # ORCID access token by authenticating via ORCID.
  def authenticated_orcid?(orcid_profile_id)
    Orcid.access_token_for(orcid_profile_id).present?
  rescue Devise::MultiAuth::AccessTokenError
    return false
  end

  def disconnect_user_and_orcid_profile(user)
    authentication_model.where(provider: 'orcid', user: user).destroy_all
    Orcid::ProfileRequest.where(user: user).destroy_all
    true
  end

  def profile_for(user)
    auth = authentication_model.where(provider: 'orcid', user: user).first
    auth && Orcid::Profile.new(auth.uid)
  end

  def enqueue(object)
    object.run
  end

  def url_for_orcid_id(orcid_profile_id)
    File.join(provider.host_url, orcid_profile_id)
  end

  def oauth_client
    # passing the site: option as Orcid's Sandbox has an invalid certificate
    # for the api.sandbox.orcid.org
    @oauth_client ||= Devise::MultiAuth.oauth_client_for(
      'orcid', options: { site: provider.site_url }
    )
  end

  def client_credentials_token(scope, collaborators = {})
    tokenizer = collaborators.fetch(:tokenizer) { oauth_client.client_credentials }
    tokenizer.get_token(scope: scope)
  end

  # As per an isolated_namespace Rails engine.
  # But the isolated namespace creates issues.
  # @api private
  def table_name_prefix
    'orcid_'
  end

  # Because I am not using isolate_namespace for Orcid::Engine
  # I need this for the application router to find the appropriate routes.
  # @api private
  def use_relative_model_naming?
    true
  end

  # Creates a profile connection using an authorization code for the users
  # ORCID account.
  # See https://members.orcid.org/api/tutorial/read-orcid-records#readlim
  def auth_user_with_code(code, user)
      uri = URI.parse(Orcid.provider.token_url)
      request = Net::HTTP::Post.new(uri)
      request["Accept"] = "application/json"
      # Note there is no redirect_uri here, since we won't follow it anyway and having one
      # can cause an error if we use an invalid redirect. Less brittle to just leave it off
      request.set_form_data( "client_id" => provider.id,
           "client_secret" => provider.secret,
           "grant_type" => "authorization_code",
           "code" => code )
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      if(response.kind_of? Net::HTTPSuccess) then
        response_json = JSON.parse(response.body)
        auth = {
          user: user,
          provider: "orcid",
          uid: response_json["orcid"],
          credentials: {
            token: response_json["access_token"],
            refresh_token: response_json["refresh_token"]
          }
        }
        Devise::MultiAuth::CaptureSuccessfulExternalAuthentication.call(user, auth)
        return true
      else
        logger.error "Error retrieving ORCID iD: #{response.body}"
      end
      return false
  end
end
