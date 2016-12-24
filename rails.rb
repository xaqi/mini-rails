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
        config.middleware.build endpoint
      end
      #@app = Proc.new{|*args| ['200',[],["hello ","rails from rails engine."]] }
    end
    class <<self
      def endpoint
        nil
      end
    end
    def endpoint
      self.class.endpoint || routes
    end
    def routes
      return 'routes'
      @routes ||= ActionDispatch::Routing::RouteSet.new_with_config(config)
      @routes
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

    #https://github.com/rails/rails/blob/master/railties/lib/rails/application/default_middleware_stack.rb
    class DefaultMiddlewareStack
      def build_stack
        ActionDispatch::MiddlewareStack.new.tap do |middleware|
          #middleware.use XXX
          #middleware.use YYY
          #middleware.use ActionController::Metal
          middleware.use ::ActionDispatch::Executor #, app.executor
        end
      end
    end

  end
  #can't find where the Application.inherited was called, temporary hard code here
  Application.inherited(Application)

end


module ActionDispatch
  #https://github.com/rails/rails/blob/master/actionpack/lib/action_dispatch/http/parameters.rb
  module Http
    module Parameters
      attr_accessor :path_parameters
    end
  end

  #https://github.com/rails/rails/blob/master/actionpack/lib/action_dispatch/http/request.rb
  class Request
    include Rack::Request::Env
    include ActionDispatch::Http::Parameters
    attr_accessor :controller_instance
    def initialize(env)
      super
    end
  end
  #https://github.com/rails/rails/blob/master/actionpack/lib/action_dispatch/http/response.rb
  class Response
    attr_accessor :request
    def self.create(status = 200, header = {}, body = [])
      new status, header, body
    end
    def initialize(status = 200, header = {}, body = [])
    end
  end

  # https://github.com/rails/rails/blob/master/actionpack/lib/action_dispatch/middleware/stack.rb
  class MiddlewareStack
    class Middleware
      attr_reader :klass
      def initialize(klass,args,block)
        @klass=klass
      end
      def build(app,*args,&block)
        klass.new(app, *args, &block)
      end
    end

    attr_accessor :middlewares
    def initialize
      @middlewares= []
    end
    def use(klass, *args, &block)
      middlewares.push(build_middleware(klass, args, block))
    end
    def build_middleware(klass, args, block)
      Middleware.new(klass, args, block)
    end
    def build(app = Proc.new)
      #return Proc.new{|*args| ['200',[],["hello ","rails from rails MiddlewareStack."]] }
      builds=middlewares.freeze.reverse.inject(app) { |a, e| e.build(a) }
      ActionController::Metal
      builds
    end
  end

  #https://github.com/rails/rails/blob/master/actionpack/lib/action_dispatch/middleware/executor.rb
  class Executor
    def initialize(app, executor=nil)
      @app, @executor = app, executor
    end
    def call(env)
      return ['200',[],["hello ","rails from Executor."] ]
      state = @executor.run! if @executor
      response = @app.call(env)
      returned = response #<< ::Rack::BodyProxy.new(response.pop) { state.complete! }
    end
  end
end

#https://github.com/rails/rails/blob/master/actionpack/lib/abstract_controller/base.rb
module AbstractController
  class Base
    attr_accessor :action_name
    def process(action, *args)
      @action_name = action.to_s
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
    def initialize
      @_request = nil
      @_response = nil
      @_routes = nil
      super
    end
    def dispatch(name,request,response)
      #return ['200',[],["hello ","rails from rails Metal Controller."]]
      set_request!(request)
      set_response!(response)
      process(name)
    end
    def set_response!(response) # :nodoc:
      @_response = response
    end
    def set_request!(request) #:nodoc:
      @_request = request
      @_request.controller_instance = self
    end
    def self.make_response!(request)
      ActionDispatch::Response.create.tap do |res|
        res.request= request
      end
    end
    def self.call(env)
      req = ActionDispatch::Request.new env
      req.path_parameters= {:action=>'list'}
      action(req.path_parameters[:action]).call(env)
    end
    def self.action(name)
      lambda { |env|
        req = ActionDispatch::Request.new(env)
        res = make_response! req
        new.dispatch(name, req, res)
      }
    end
    def index(*args)
      ['200',[],["hello ","rails from rails Action Index."]]
    end
    def list(*args)
      ['200',[],["hello ","rails from rails Action List."]]
    end
  end
  #https://github.com/rails/rails/blob/master/actionpack/lib/action_co
  class Base < Metal
  end

end


