# List all tasks from RAILS_ROOT using: cap -T
#
# NOTE: The SCM command expects to be at the same path on both the local and
# remote machines. The default git path is: '/shared/git/bin/git'.

#############################################################
#  Settings
#############################################################

default_run_options[:pty] = true
set :use_sudo, false
ssh_options[:paranoid] = false

#############################################################
#  SCM
#############################################################

set :scm, :git
set :deploy_via, :remote_cache
set :scm_command, '/shared/git/bin/git'

#############################################################
#  Environment
#############################################################

namespace :env do
  desc "Set command paths"
  task :set_paths do
    set :ruby,      File.join(ruby_bin, 'ruby')
    set :bundler,   File.join(ruby_bin, 'bundle')
    set :rake,      "#{bundler} exec #{File.join(shared_path, 'vendor/bundle/bin/rake')}"
  end
end

#############################################################
#  Passenger
#############################################################

desc "Restart Application"
task :restart_passenger do
  run "touch #{current_path}/tmp/restart.txt"
end

#############################################################
#  Database
#############################################################

namespace :db do
  desc "Run the seed rake task."
  task :seed, :roles => :app do
    run "cd #{current_path}; #{rake} RAILS_ENV=#{rails_env} db:seed"
  end
end

#############################################################
#  Deploy
#############################################################

namespace :deploy do
  desc "Execute various commands on the remote environment"
  task :debug, :roles => :app do
    run "/usr/bin/env", :pty => false, :shell => '/bin/bash'
    run "whoami"
    run "pwd"
    run "echo $PATH"
    run "which ruby"
    run "ruby --version"
    run "which rake"
    run "rake --version"
    run "which bundle"
    run "bundle --version"
    run "which git"
  end

  desc "Start application in Passenger"
  task :start, :roles => :app do
    restart_passenger
  end

  desc "Restart application in Passenger"
  task :restart, :roles => :app do
    restart_passenger
  end

  task :stop, :roles => :app do
    # Do nothing.
  end

  desc "Run the migrate rake task."
  task :migrate, :roles => :app do
    run "cd #{release_path}; #{rake} RAILS_ENV=#{rails_env} db:migrate"
  end

  desc "Symlink shared configs and folders on each release."
  task :symlink_shared do
    symlink_targets.each do | source, destination, shared_directory_to_create |
      run "mkdir -p #{File.join( shared_path, shared_directory_to_create)}"
      run "ln -nfs #{File.join( shared_path, source)} #{File.join( release_path, destination)}"
    end
  end

  desc "Spool up Passenger spawner to keep user experience speedy"
  task :kickstart do
    run "curl -I http://#{domain}"
  end

  desc "Precompile assets"
  task :precompile do
    run "cd #{release_path}; #{rake} RAILS_ENV=#{rails_env} RAILS_GROUPS=assets assets:precompile"
  end
end

namespace :bundle do
  desc "Install gems in Gemfile"
  task :install, :roles => [:app, :work] do
    switches = ""
    switches << " --binstubs='#{release_path}/vendor/bundle/bin'"
    switches << " --shebang '#{ruby}'"
    switches << " --path=#{release_path}/vendor/bundle"
    switches << " --gemfile='#{release_path}/Gemfile'"
    switches << " --deployment"
    switches << " --without #{without_bundle_environments}"
    run "#{bundler} install #{switches}"
  end
end

namespace :worker do
  task :start, :roles => :work do
    target_file = "/home/curatend/resque-pool-info"
    run [
      "echo \"RESQUE_POOL_ROOT=$(pwd)/current\" > #{target_file}",
      "echo \"RESQUE_POOL_ENV=#{fetch(:rails_env)}\" >> #{target_file}",
      "sudo /sbin/service resque-poold restart"
    ].join(" && ")
  end
end

namespace :maintenance do
  task :create_person_records, :roles => :app do
    run "cd #{current_path} && #{File.join(ruby_bin, 'bundle')} exec rails runner #{File.join(current_path, 'script/sync_person_with_user.rb')} -e #{rails_env}"
  end
  task :delete_index_solr, :roles => :app do
    config = capture("cat #{current_path}/config/solr.yml")
    solr_core_url = Psych.load(config).fetch(rails_env).fetch('url')
    run "curl #{File.join(solr_core_url, 'update')}?commit=true -H 'Content-Type:application/xml' -d '<delete><query>*:*</query></delete>'"
  end
  task :reindex_solr, :roles => :app do
    run "cd #{current_path} && #{File.join(ruby_bin, 'bundle')} exec rails runner 'Sufia.queue.push(ReindexWorker.new)' -e #{rails_env}"
  end
  before 'maintenance:reindex_solr', 'maintenance:delete_index_solr'
end

set(:secret_repo_name) {
  case rails_env
  when 'staging' then 'secret_staging'
  when 'pre_production' then 'secret_pprd'
  when 'production' then 'secret_prod'
  end
}

namespace :und do
  task :update_secrets do
    run "cd #{release_path} && ./script/update_secrets.sh #{secret_repo_name}"
  end

  task :write_build_identifier, :roles => :app do
    run "cd #{release_path} && echo '#{build_identifier}' > config/bundle-identifier.txt"
  end
end

#############################################################
#  Callbacks
#############################################################

before 'deploy', 'env:set_paths'

#############################################################
#  Configuration
#############################################################

set :application, 'curate_nd'
set :repository,  "git://github.com/ndlib/curate_nd.git"

set :build_identifier, Time.now.strftime("%Y-%m-%d %H:%M:%S")

#############################################################
#  Environments
#############################################################

def set_common_cluster_variables(cluster_directory_slug)
  set :symlink_targets do
    [
      ['/bundle/config','/.bundle/config', '/.bundle'],
      ['/log','/log','/log'],
      ['/vendor/bundle','/vendor/bundle','/vendor'],
    ]
  end
  set :git_bin,    '/shared/git/bin'
  set :without_bundle_environments, 'headless development test'

  set :deploy_to,   "/shared/#{cluster_directory_slug}/data/app_home/curate"
  set :ruby_bin,    "/shared/#{cluster_directory_slug}/ruby/1.9.3/bin"

  default_environment['PATH'] = "#{git_bin}:#{ruby_bin}:$PATH"
  server "#{user}@#{domain}", :app, :web, :db, :primary => true

  after 'deploy:update_code', 'und:write_build_identifier', 'und:update_secrets', 'deploy:symlink_shared', 'bundle:install', 'deploy:migrate', 'deploy:precompile'
  after 'deploy', 'deploy:cleanup'
  after 'deploy', 'deploy:restart'
  after 'deploy', 'deploy:kickstart'
end

desc "Setup for the Pre-Production environment"
task :pre_production_cluster do
  set :branch, "master"
  set :rails_env,   'pre_production'

  set :user,        'rbpprd'
  set :domain,      'curatepprd.library.nd.edu'

  set_common_cluster_variables('ruby_pprd')
end

desc "Setup for the Production environment"
task :production_cluster do
  set :branch,      'release'
  set :rails_env,   'production'

  set :user,        'rbprod'
  set :domain,      'curateprod.library.nd.edu'

  set_common_cluster_variables('ruby_prod')
end


# Trying to keep the worker environments as similar as possible
def common_worker_things
  set :symlink_targets do
    [
      [ '/bundle/config', '/.bundle/config', '/bundle'],
      [ '/log', '/log', '/log'],
      [ '/vendor/bundle', '/vendor/bundle', '/vendor/bundle'],
    ]
  end
  set :scm_command, '/usr/bin/git'
  set :deploy_to,   '/home/curatend'
  set :ruby_bin,    '/usr/local/ruby/bin'
  set :without_bundle_environments, 'development test'
  set :group_writable, false

  default_environment['PATH'] = "#{ruby_bin}:$PATH"
  server "#{user}@#{domain}", :work
  after 'deploy', 'worker:start'
  after 'deploy:update_code', 'und:update_secrets', 'deploy:symlink_shared', 'bundle:install'
end

desc "Setup for the Staging Worker environment"
task :staging_worker do
  set :rails_env,   'staging'
  set :user,        'curatend'
  set :domain,      'curatestagingw1.library.nd.edu'
  set :branch, "master"
  common_worker_things
end

desc "Setup for the Preproduction Worker environment"
task :pre_production_worker do
  set :rails_env,   'pre_production'
  set :user,        'curatend'
  set :domain,      'curatepprdw1.library.nd.edu'
  set :branch, "master"
  common_worker_things
end

desc "Setup for the Production Worker environment"
task :production_worker do
  set :rails_env,   'production'
  set :user,        'curatend'
  set :domain,      'curateprodw1.library.nd.edu'
  set :branch,      'release'
  common_worker_things
end
