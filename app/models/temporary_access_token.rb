class TemporaryAccessToken < ActiveRecord::Base
  self.primary_key = 'sha'
  paginates_per 15

  def self.hours_until_expiry
    24
  end

  def self.permitted?(noid, sha)
    valid_tokens(noid, sha).any?
  end

  def self.use!(sha)
    tokens = self.where(sha: sha)
    updated_tokens  = []

    tokens.each do |token|
      if token.expiry_date.blank?
        token.update_attribute(:expiry_date, new_expiry_date)
        updated_tokens << token
      end
    end

    updated_tokens.any?
  end

  def self.valid_tokens(noid, sha)
    self.where(noid: noid, sha: sha).where("#{self.quoted_table_name}.`expiry_date` IS NULL OR #{self.quoted_table_name}.`expiry_date` >= ?", Time.now)
  end
  private_class_method :valid_tokens

  def self.new_expiry_date
    Time.now + hours_until_expiry.hours
  end
  private_class_method :new_expiry_date

  validates_presence_of :noid, :issued_by
  validates_uniqueness_of :sha
  before_create :assign_new_sha, :strip_pid_namespace
  before_update :reset_expiry_date_if_prompted
  attr_accessor :reset_expiry_date

  def assign_new_sha
    assign_attributes(sha: generate_sha)
  end
  private :assign_new_sha

  def generate_sha
    SecureRandom.urlsafe_base64(32, false)
  end
  private :generate_sha

  def reset_expiry_date_if_prompted
    if reset_expiry_date
      self.expiry_date = nil
    end
  end
  private :reset_expiry_date_if_prompted

  def strip_pid_namespace
    assign_attributes(noid: Sufia::Noid.noidify(noid))
  end
  private :strip_pid_namespace

  def obsolete?
    if expiry_date.nil?
      # obsolete if never used and not modified in last 90 days
      return updated_at < Date.today - 90
    else
      # obsolete if past expiry_date
      return expiry_date < Date.today
    end
  end

  def user_is_editor(user)
    return false if user.nil?
    begin
      return user.can? :edit, Sufia::Noid.namespaceize(noid)
    rescue ActiveFedora::ObjectNotFoundError
      return false
    end
  end
end
