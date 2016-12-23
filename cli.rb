require_relative 'server'
#https://github.com/rails/rails/blob/master/railties/lib/rails/cli.rb
ARGV=['server']
Rails::AppLoader.exec_app
Rails::Command.invoke :application, ARGV