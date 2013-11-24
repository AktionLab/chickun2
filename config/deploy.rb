require 'capistrano/ext/multistage'
require 'bundler/capistrano'
require 'rvm/capistrano'
require './config/boot'
#require 'airbrake/capistrano'

set :stages, %w(production staging)

ssh_options[:username] = 'deployer'
ssh_options[:forward_agent] = true

set :application, 'chickun2'
set :repository, "git@github.com:AktionLab/#{application}.git"
set :scm, :git
set :deploy_via, :remote_cache
set(:deploy_to) { "/var/www/#{application}/#{stage}" }
set :rvm_type, :user
set :rvm_ruby_string, "2.0.0-p247@#{application}"
set :use_sudo, false
set :server_hostname, "54.205.158.135"
set :port, 2234
set(:rails_env) { stage }

set :symlinks, %w(config/database.yml config/unicorn.rb data)

role :web, server_hostname
role :app, server_hostname
role :db, server_hostname, :primary => true

before 'deploy:assets:precompile', 'deploy:symlink_shared'
after  'deploy:assets:precompile', 'deploy:db:migrate'
after  'deploy:db:migrate',        'nginx:config'
after  'nginx:config',             'nginx:reload'
after  'deploy',                   'deploy:cleanup'

namespace :deploy do
  task :start do
    run "cd #{current_path} && bundle exec unicorn -c #{shared_path}/config/unicorn.rb -E #{stage} -D"
  end

  task :stop do
    run "kill `cat #{shared_path}/pids/unicorn.pid`; true"
  end

  task :restart do
    stop
    start
  end

  task :symlink_shared, :except => {:no_release => true} do
    run(symlinks.map {|link| "ln -nfs #{shared_path}/#{link} #{release_path}/#{link}"}.join(' && '))
  end

  namespace :db do
    task :backup, :except => {:no_release => true} do
      run "cd #{release_path} && RAILS_ENV=#{stage} bundle exec rake db:backup"
    end

    task :migrate, :except => {:no_release => true} do
      #backup
      run "cd #{release_path} && RAILS_ENV=#{stage} bundle exec rake db:migrate"
    end

    task :seed, :except => {:no_release => true} do
      run "cd #{release_path} && RAILS_ENV=#{stage} bundle exec rake db:seed"
    end
  end
end

namespace :nginx do
  task :config do
    run "sudo rm -f /etc/nginx/default && sudo ln -nfs #{release_path}/config/nginx_#{stage}.conf /etc/nginx/sites-enabled/default"
  end

  task :reload do
    run "sudo /etc/init.d/nginx reload"
  end
end
