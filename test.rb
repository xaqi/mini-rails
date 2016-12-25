require_relative 'mini-rails'

class HomeController < ActionController::Base
  def index
    ['200',[],["hello from Home Index."]]
  end
end

class UserController < ActionController::Base
  def about
    ['200',[],["hello from User About."]]
  end
end

start_server
