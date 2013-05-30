module FeatureSupport
  def with_javascript?
    @example.metadata[:js] || @example.metadata[:javascript]
  end

  def login_as(user)
    user.reload # because the user isn't re-queried via Warden
    super(user, scope: :user, run_callbacks: false)
  end

  module_function
  def options(default = {type: :feature})
    if ENV['JS']
      Capybara.javascript_driver = default.fetch(:javascript_driver, :poltergeist_debug)
      default[:js] = true
    else
      Capybara.javascript_driver = default.fetch(:javascript_driver, :poltergeist)
    end
    default
  end

end
