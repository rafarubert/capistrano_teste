require 'bundler/capistrano'
set :rvm_type, :system
require 'rvm/capistrano'
load "deploy/assets"

set :application, "midah.com.br"
set :repository,  "git@github.com:sevana/presentear.git"

set :scm, :git
set :deploy_via, :remote_cache

set :branch, "master"
default_run_options[:pty] = true
set :user, "railsapps"
set :use_sudo, false
set :deploy_to, "/home/#{user}/#{application}"
set :deploy_via, :export
server application, :app, :web, :db, :primary => true

after 'deploy:update_code', 'deploy:restart'
after 'deploy:restart', 'deploy:database_link'
after 'deploy:database_link', 'deploy:database_migrate'
after 'deploy:execute_bundler', 'deploy:assets_precompile'
after 'deploy:assets_precompile', 'deploy:update_crontab'

namespace :deploy do
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end

  task :database_link do
    run "rm -rf #{release_path}/config/database.yml"
    run "ln -s #{deploy_to}/database.yml #{release_path}/config/database.yml"
  end

  task :database_migrate do
    run "cd #{deploy_to}/current && RAILS_ENV=production #{bundle_cmd} exec rake db:migrate"
  end

  task :assets_precompile do
    run "cd #{deploy_to}/current && RAILS_ENV=production bundle exec rake assets:precompile"
  end
  namespace :assets do
    task :assets_precompile, :roles => :web, :except => { :no_release => true } do
      if remote_file_exists?(current_path)
        from = source.next_revision(current_revision)
        if capture("cd #{latest_release} && #{source.local.log(from)} vendor/assets/ app/assets/ | wc -l").to_i > 0
          run %Q{cd #{latest_release} && #{rake} RAILS_ENV=#{rails_env} #{asset_env} assetsrecompile}
        else
          logger.info "Skipping asset pre-compilation because there were no asset changes"
        end
      else
        run %Q{cd #{latest_release} && #{rake} RAILS_ENV=#{rails_env} #{asset_env} assetsrecompile}
      end
    end
  end
  task :update_crontab do
    run "cd #{deploy_to}/current && whenever --update-crontab"
  end
end