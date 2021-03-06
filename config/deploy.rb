require "bundler/capistrano"
set :default_environment, {
  'PATH' => "/home/felipillo/.rvm/rubies/ruby-2.0.0-p195/bin:/home/felipillo/.rvm/gems/ruby-2.0.0-p195/bin/:$PATH"
}
server "54.214.242.160", :web, :app, :db, primary: true

set :ssh_options, {:forward_agent => true}
set :application, "blog"
set :user, "felipillo"
set :deploy_to, "/home/#{user}/#{application}"
set :deploy_via, :remote_cache
#set :deploy_via, :copy
set :use_sudo, false

set :scm, "git"
set :repository, "git@github.com:friveroll/#{application}.git"
set :branch, "master"


default_run_options[:pty] = true
ssh_options[:forward_agent] = true
ssh_options[:keys] = [File.join(ENV["HOME"], ".ssh", "aws")]

after "deploy", "deploy:cleanup" # keep only the last 5 releases

namespace :deploy do
  %w[start stop restart].each do |command|
    desc "#{command} unicorn server"
    task command, roles: :app, except: {no_release: true} do
      run "/etc/init.d/unicorn_#{application} #{command}"
    end
  end

  task :setup_config, roles: :app do
    sudo "ln -nfs #{current_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
    sudo "ln -nfs #{current_path}/config/unicorn_init.sh /etc/init.d/unicorn_#{application}"
    run "mkdir -p #{shared_path}/config"
    put File.read("config/database.default.yml"), "#{shared_path}/config/database.yml"
    puts "Now edit the config files in #{shared_path}."
  end
  after "deploy:setup", "deploy:setup_config"

  task :symlink_config, roles: :app do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
  end
  after "deploy:finalize_update", "deploy:symlink_config"

  desc "Make sure local git is in sync with remote."
  task :check_revision, roles: :web do
    unless `git rev-parse HEAD` == `git rev-parse origin/master`
      puts "WARNING: HEAD is not the same as origin/master"
      puts "Run `git push` to sync changes."
      exit
    end
  end
  before "deploy", "deploy:check_revision"
end
