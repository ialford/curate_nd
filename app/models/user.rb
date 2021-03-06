class User < ActiveRecord::Base

  # Connects this user object to Hydra behaviors.
  include Hydra::User
  # Connects this user object to Blacklights Bookmarks.
  include Blacklight::User

  include Curate::UserBehavior
  # Adds acts_as_messageable for user mailboxes
  include Mailboxer::Models::Messageable

  def self.search(query = nil)
    if query.to_s.strip.present?
      term = "#{query.to_s.upcase}%"
      where("UPPER(email) LIKE :term OR UPPER(name) LIKE :term OR UPPER(username) LIKE :term", {term: term})
    else
      all
    end.order(:username)
  end

  def self.from_omniauth(auth)
    # This is the nested structure of the token sent back by Okta
    username = auth.extra.raw_info.netid
    name = auth.extra.raw_info.name
    email = auth.extra.raw_info.email
    # * We need to find/create the user by NetID, then consider registering a corresponding
    #   Authentication for provider/uid
    # We then need to save the user and return it
    user = FindOrCreateUser.call(username, name)
  end

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :registerable, :rememberable, :trackable, :validatable, :masqueradable, :omniauthable, :omniauth_providers => [:orcid, :oktaoauth]

  attr_accessor :password

  def password_required?; false; end
  def email_required?; false; end

  def update_with_password(attributes)
    self.update(attributes)
  end

  def self.audituser
    User.find_by_user_key(audituser_key) || User.create!(Devise.authentication_keys.first => audituser_key)
  end

  def self.audituser_key
    'curate_nd_audituser'
  end

  def self.batchuser
    User.find_by_user_key(batchuser_key) || User.create!(Devise.authentication_keys.first => batchuser_key)
  end

  def self.batchuser_key
    'curate_nd_batchuser'
  end

  # Method added by Blacklight; Blacklight uses #to_s on your
  # user class to get a user-displayable login/identifier for
  # the account.
  def to_s
    username
  end

  def to_param
    id
  end
end
