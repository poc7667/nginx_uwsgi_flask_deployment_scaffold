# config valid only for current version of Capistrano
lock '3.4.0'

set :application, 'recipe'
set :repo_url, ENV["GIT_REPO"]
set :deploy_to, ENV["DEPLOY_PATH"]
set :working_path, ENV['LOCAL_WOKRING_PATH']
set :branch, ENV["BRANCH"] || `git rev-parse --abbrev-ref HEAD`.chop
set :user, ENV["DEPLOYER"]
set :use_sudo, false
set :rbenv_ruby, "2.2.2"
set :rbenv_path, "#{ENV['DEPLOYER_HOME']}/.rbenv"
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w(rake gem bundle ruby rails)
set :rbenv_roles, :all 
set :rbenv_type, :user
set :bundle_flags, "--deployment --quiet --binstubs --shebang ruby-local-exec"
set :default_env, { path: "~/.rbenv/shims:~/.rbenv/bin:$PATH" }
set :default_environment, {
  'PATH' => "$HOME/.rbenv/shims:$HOME/.rbenv/bin:$HOME/bin:$HOME/local/bin:$PATH"
}

set :nginx_sites_enabled_path, "/etc/nginx/sites-enabled/"
set :uwsgi_path, '/etc/uwsgi/'

namespace :nginx do

  task :setup do
    on roles(:web) do |host|
      upload! "#{fetch(:working_path)}/config/nginx.conf", "#{deploy_to}/current/config/nginx.conf"
      execute " cd #{fetch(:nginx_sites_enabled_path)} && sudo ln -sf #{deploy_to}/current/config/nginx.conf #{ENV['APP_NAME']}  &&  sudo /etc/init.d/nginx reload "
    end
  end  

   task :update do
      on roles(:web) do |host|
        execute " sudo /etc/init.d/nginx restart "
      end
   end
end

namespace :uwsgi do

  task :deploy do |host|
    on roles(:web) do |host|
      execute "sudo pkill -9 uwsgi", raise_on_non_zero_exit: false
      execute "cd #{deploy_to}/current && source $HOME/.zshrc  && sudo foreman export -d #{ENV['WEB_SERVER_RELATIVE_WORKING_DIR']}  -e .env -f uwsgi_procfile upstart /etc/init -a #{ENV['APP_NAME']} -u #{fetch(:user)} -l /var/#{ENV['APP_NAME']}.log", raise_on_non_zero_exit: false
      execute "sudo stop kyper_wsh-web-1", raise_on_non_zero_exit: false
      execute "sudo start kyper_wsh-web-1", raise_on_non_zero_exit: false
    end
  end

end

namespace :system do

  task :misc_tasks do
    on roles(:web) do
      upload! "#{fetch(:working_path)}/.env", "#{deploy_to}/current/.env", raise_on_non_zero_exit: false
      execute "cd #{deploy_to}/current && bundle exec whenever --update-crontab #{fetch(:user)} ", raise_on_non_zero_exit: false
    end
  end

end

namespace :deploy do
  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
    end
  end
end

after 'deploy:published', 'nginx:setup'
after 'deploy:published', 'nginx:update'

after 'deploy:published', 'system:misc_tasks'
after 'deploy:published', 'uwsgi:deploy'