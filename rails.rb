module Rails

  class << self
    #https://github.com/rails/rails/blob/master/railties/lib/rails.rb#L36
    @application = @app_class = nil
    attr_writer :application
    attr_accessor :app_class
    def application
      @application ||= (app_class.instance if app_class)
    end
  end

  #https://github.com/rails/rails/blob/master/railties/lib/rails/engine.rb
  class Engine
    def call(env)
      req = build_request env
      app.call req.env
    end
    def app
      @app ||= begin
        stack = default_middleware_stack
        config.middleware = config.middleware.merge_into stack
        config.middleware.build
      end
      #@app = Proc.new{|*args| ['200',[],["hello ","rails from rails engine."]] }
    end
    def self.instance
      new
    end
    def build_request(env)
      req = ActionDispatch::Request.new env
      # req.routes = routes
      # req.engine_script_name = req.script_name
      req
    end
    def config
      @config ||= Engine::Configuration.new
    end
    def default_middleware_stack
      ActionDispatch::MiddlewareStack.new
    end

    class Configuration #< ::Rails::Railtie::Configuration
      attr_accessor :middleware
      def initialize
        @middleware = Rails::Configuration::MiddlewareStackProxy.new
      end

    end
  end

  module Configuration
    class MiddlewareStackProxy
      def merge_into(other)
        other
      end
    end
  end

  #https://github.com/rails/rails/blob/master/railties/lib/rails/application.rb
  class Application < Engine
    class << self
      def inherited(base)
        Rails.app_class = base
      end
    end
    def default_middleware_stack
      default_stack = DefaultMiddlewareStack.new
      default_stack.build_stack
    end

    class DefaultMiddlewareStack
      def build_stack
        ActionDispatch::MiddlewareStack.new.tap do |middleware|
          #middleware.use XXX
          #middleware.use YYY
        end
      end
    end

  end
  #can't find where the Application.inherited was called, temporary hard code here
  Application.inherited(Application)

end


module ActionDispatch
  #https://github.com/rails/rails/blob/master/actionpack/lib/action_dispatch/http/request.rb
  class Request
    include Rack::Request::Env
    def initialize(env)
      super
    end
  end
  class Response
    attr_accessor :request
    def self.create(status = 200, header = {}, body = [])
      new status, header, body
    end
    def initialize(status = 200, header = {}, body = [])
    end
  end
  class MiddlewareStack
    def build
      #Proc.new{|*args| ['200',[],["hello ","rails from rails MiddlewareStack."]] }
      ActionController::Metal
    end
  end
end

#https://github.com/rails/rails/blob/master/actionpack/lib/abstract_controller/base.rb
module AbstractController
  class Base
    def process(action, *args)
      process_action(action_name, *args)
    end
    def process_action(method_name, *args)
      send_action(method_name, *args)
    end
    alias send_action send
  end
end
module ActionController
  class MiddlewareStack < ActionDispatch::MiddlewareStack
    # class Middleware < ActionDispatch::MiddlewareStack::Middleware
    #
    # end
  end

  #https://github.com/rails/rails/blob/master/actionpack/lib/action_controller/metal.rb
  class Metal < AbstractController::Base
    def dispatch(name,request,response)
      # set_request!(request)
      # set_response!(response)
      # process(name)
      ['200',[],["hello ","rails from rails Metal Controller."]]
    end
    def self.make_response!(request)
      ActionDispatch::Response.create.tap do |res|
        res.request = request
      end
    end
    def self.call(env)
      req = ActionDispatch::Request.new env
      #action(req.path_parameters[:action]).call(env)
      action('req.path_parameters[:action]').call(env)
    end
    def self.action(name)
      lambda { |env|
        req = ActionDispatch::Request.new(env)
        res = make_response! req
        new.dispatch(name, req, res)
      }
    end
  end
  #https://github.com/rails/rails/blob/master/actionpack/lib/action_co
  class Base < Metal

  end

end


