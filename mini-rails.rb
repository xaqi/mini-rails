require 'socket'
require 'thread'

module WEBrick

  module Utils
    #https://github.com/candlerb/webrick/blob/master/lib/webrick/utils.rb
    def create_listeners
      address='0.0.0.0'
      port=8081
      res = Socket::getaddrinfo(address, port, Socket::AF_UNSPEC, Socket::SOCK_STREAM, 1, Socket::AI_PASSIVE)
      sockets = []
      res.each{|ai|
        puts ("TCPServer.new(#{ai[3]}, #{port})")
        sock = TCPServer.new(ai[3], port)
        sockets << sock
      }
      sockets
    end
    module_function :create_listeners
  end

  #https://github.com/candlerb/webrick/blob/master/lib/webrick/server.rb
  class SimpleServer
    def SimpleServer.start
      yield
    end
  end

  #https://github.com/candlerb/webrick/blob/master/lib/webrick/server.rb
  class GenericServer
    def start
      @listeners = Utils::create_listeners
      SimpleServer.start{
        while true
          svrs = IO.select(@listeners, nil, nil, 2.0)
          if svrs
            svrs[0].each{|svr|
              sock = svr.accept
              sock.sync = true
              start_thread sock if sock
            }
          end
        end
      }
    end
    def run(sock)
      raise 'run() must be provided by user.'
    end
    def start_thread(sock)
      Thread.start{
        begin
          run sock
        ensure
          sock.close
        end
      }
    end
  end

  #https://github.com/candlerb/webrick/blob/master/lib/webrick/httprequest.rb
  class HTTPRequest
    LF="\n"
    def parse(socket=nil)
      @request = socket.gets LF,4096
      puts @request
      @path_info = @request
    end
    def path
      '/'
    end
    def meta_vars
      meta = Hash.new
      meta["PATH_INFO"]         = @path_info
      meta
    end
  end

  #https://github.com/candlerb/webrick/blob/master/lib/webrick/httpresponse.rb
  class HTTPResponse
    attr_reader :header, :body
    def initialize
      @header=Hash.new
      @body=[]
    end
    def send_response(sock)
      sock << "HTTP/1.1 200/OK\r\nContent-type:text/html\r\n\r\n"
      @body.each { |part| sock << part }
    end
  end

  #https://github.com/candlerb/webrick/blob/master/lib/webrick/httpserver.rb
  class HTTPServer < GenericServer
    def initialize
      @mount_tab = Hash.new
    end
    def run(sock)
      req=HTTPRequest.new
      res=HTTPResponse.new
      req.parse sock
      self.service(req, res)
      res.send_response(sock)
      sock.close
    end
    def service(req, res)
      servlet, options = search_servlet req.path
      si = servlet.get_instance self, *options
      si.service req, res
    end
    def search_servlet(path)
      @mount_tab[path]
    end
    def mount(dir,servlet,*options)
      @mount_tab[dir] = [servlet,options]
    end
  end

end

#WEBrick::HTTPServer.new.start

module WEBrick
  module HTTPServlet

    #https://github.com/candlerb/webrick/blob/master/lib/webrick/httpservlet/abstract.rb
    class AbstractServlet
      def initialize(server, *options)
        @server = server
        @options = options
      end
      def self.get_instance(server,*options)
        self.new server,*options
      end
      def service(req, res)
        raise 'service(req, res) must be provided by user.'
      end
    end

  end
end

module Rack
  module Handler

    def self.default
      Rack::Handler::WEBrick
    end

    #https://github.com/rack/rack/blob/master/lib/rack/handler/webrick.rb
    class WEBrick < ::WEBrick::HTTPServlet::AbstractServlet
      def self.run(app)
        @server = ::WEBrick::HTTPServer.new
        @server.mount '/',Rack::Handler::WEBrick, app
        @server.start
      end
      def initialize(server, app)
        super server
        @app = app
      end
      def service(req, res)
        env = req.meta_vars
        status, headers, body = @app.call(env)
        body.each { |part| res.body << part }
      end
    end

  end

  #https://github.com/rack/rack/blob/master/lib/rack/server.rb
  class Server
    def self.start
      new.start
    end
    def start &blk
      server.run wrapped_app, &blk
    end
    def server
      @_server = Rack::Handler.default
    end
    def build_app_and_options_from_config
      app = Rack::Builder.parse_file 'config.ru'
    end
    def wrapped_app
      @wrapped_app ||= build_app app
    end
    def app
      @app ||= build_app_and_options_from_config
    end
    def build_app(app)
      middleware.reverse_each do |middleware|
        middleware = middleware.call(self)
        klass, *args = middleware
        app = klass.new(app, *args)
      end
      app
    end
    def middleware
      self.class.middleware
    end
  end

  #https://github.com/rack/rack/blob/master/lib/rack/builder.rb
  class Builder
    def self.parse_file(config)
      cfgfile='Rails.application' #read config.ru
      app=new_from_string cfgfile
      app
    end
    def self.new_from_string(builder_script)
      app = eval "Rack::Builder.new {\n" + builder_script + "\n}.to_app"
    end
    def initialize(default_app = nil,&block)
      @run =  default_app
      @run = instance_eval(&block) if block_given?
    end
    def to_app
      app = @run
      app
    end
  end

  class Request
    module Env
      attr_reader :env
      def initialize(env)
        @env=env
        super()
      end
    end
  end
end

#Rack::Server.start
module Rails

  #https://github.com/rails/rails/blob/master/railties/lib/rails/commands/server/server_command.rb
  class Server < ::Rack::Server
    def initialize
      super
    end
    def start
      super
    end
    def middleware
      Hash.new([])
    end
  end

  module Command

    #https://github.com/rails/rails/blob/56b3849316b9c4cf4423ef8de30cbdc1b7e0f7af/railties/lib/rails/command/actions.rb
    module Actions
    end
    class Base
      include Actions
    end

    #https://github.com/rails/rails/blob/master/railties/lib/rails/commands/server/server_command.rb
    class ServerCommand < Base
      def perform
        #require APP_PATH
        Rails::Server.new.tap do |server|
          server.start
        end
      end
    end

    #https://github.com/rails/rails/blob/master/railties/lib/rails/commands/application/application_command.rb
    class ApplicationCommand < Base
      def perform(*args)
        Rails::Command::ServerCommand.new.perform
      end
    end

    #https://github.com/rails/rails/blob/master/railties/lib/rails/command.rb
    class << self
      def invoke(namespace,args)
        command=find_by_namespace namespace
        command.perform namespace,args
      end
      def find_by_namespace(namespace)
        case namespace
          when :application
            Rails::Command::ApplicationCommand.new
        end
      end
    end

  end

  module AppLoader
    extend self
    def exec_app
      Object.const_set(:APP_PATH, File.expand_path("config/application", Dir.pwd))
    end
  end
end




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
      #@app = Proc.new{|*args| ['200',[],["hello from rails engine."]] }
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
      @routes ||= ActionDispatch::Routing::RouteSet.new_with_config(config)
      @routes
    end
    def self.instance
      new
    end
    def build_request(env)
      req = ActionDispatch::Request.new env
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
      def path_parameters
        m=/\/([^\/]+)(?:\/?([^\/]+))?\/?\s/.match env["PATH_INFO"].strip
        {:action=>$2 || 'index',:controller=>$1 || 'Home'}
      end
    end
  end

  #https://github.com/rails/rails/blob/master/actionpack/lib/action_dispatch/http/request.rb
  class Request
    include Rack::Request::Env
    include ActionDispatch::Http::Parameters
    attr_accessor :controller_instance, :path_info
    def initialize(env)
      super
    end

    def controller_class
      params = path_parameters
      controller_param = params[:controller]
      params[:action] ||= "index"
      const_name = "#{controller_param}Controller"
      #ActiveSupport::Dependencies.constantize(const_name)
      eval const_name
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
      #return Proc.new{|*args| ['200',[],["hello from rails MiddlewareStack."]] }
      builds=middlewares.freeze.reverse.inject(app) { |a, e| e.build(a) }
      builds
    end
  end

  #https://github.com/rails/rails/blob/master/actionpack/lib/action_dispatch/middleware/executor.rb
  class Executor
    def initialize(app, executor=nil)
      @app, @executor = app, executor
    end
    def call(env)
      #return ['200',[],["hello from Executor."] ]
      #state = @executor.run! if @executor
      response = @app.call(env)
    end
  end

  module Routing
    #https://github.com/rails/rails/blob/master/actionpack/lib/action_dispatch/routing/endpoint.rb
    class Endpoint
      def app;           self;  end
    end

    #https://github.com/rails/rails/blob/master/actionpack/lib/action_dispatch/routing/route_set.rb
    class RouteSet
      class Dispatcher < Routing::Endpoint
        def serve(req)
          #return ['200',[],["hello from RouteSet Dispatcher."] ]
          begin
            params     = req.path_parameters
            controller = controller req
            res        = controller.make_response! req
            dispatch(controller, params[:action], req, res)
          rescue
            ['200',[],["404"] ]
          end
        end
        def dispatch(controller, action, req, res)
          controller.dispatch(action, req, res)
        end
        def controller(req)
          req.controller_class
        end
      end

      Config = Struct.new :relative_url_root, :api_only
      DEFAULT_CONFIG = Config.new(nil, false)
      def self.new_with_config(config)
        route_set_config = DEFAULT_CONFIG
        new route_set_config
      end
      def initialize(config = DEFAULT_CONFIG)
        @set    = Journey::Routes.new
        @router = Journey::Router.new @set
        #Routes should be set by route mapping registers, hard code here for simplicity
        @set.instance_eval{ @routes << Dispatcher.new }
      end
      def call(env)
        req = make_request(env)
        req.path_info = Journey::Router::Utils.normalize_path(req.path_info)
        @router.serve(req)
      end
      def request_class
        ActionDispatch::Request
      end
      def make_request(env)
        request_class.new env
      end
    end
  end

  module Journey
    #https://github.com/rails/rails/blob/master/actionpack/lib/action_dispatch/journey/router.rb
    class Router
      attr_accessor :routes
      def initialize(routes)
        @routes = routes
      end
      def serve(req)
        #return ['200',[],["hello from Router."] ]
        find_routes(req).each do |match, parameters, route|
          status, headers, body = route.app.serve(req)
          return [status, headers, body]
        end
      end
      def find_routes(req)
        routes.map{|x|[nil,nil,x]}
      end
      class Utils
        def self.normalize_path(path)
          path = "/#{path}"
          path.squeeze!("/".freeze)
          path.sub!(%r{/+\Z}, "".freeze)
          path.gsub!(/(%[a-f0-9]{2})/) { $1.upcase }
          path = "/" if path == "".freeze
          path
        end
      end
    end

    #https://github.com/rails/rails/blob/master/actionpack/lib/action_dispatch/journey/routes.rb
    class Routes
      include Enumerable
      attr_reader :routes
      def initialize
        @routes             = []
      end
      def each(&block)
        routes.each(&block)
      end
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
      #return ['200',[],["hello from rails Metal Controller."]]
      set_request!(request)
      set_response!(response)
      process(name)
    end
    def self.dispatch(name, req, res)
      new.dispatch name,req,res
    end
    def set_response!(response) # :nodoc:
      @_response = response
    end
    def set_request!(request) #:nodoc:
      @_request = request
      @_request.controller_instance = self
    end
    def self.make_response!(request)
      ActionDispatch::Response.create.tap do |res| res.request= request end
    end
    def self.call(env)
      req = ActionDispatch::Request.new env
      action(req.path_parameters[:action]).call(env)
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


def start_server
  Rails::AppLoader.exec_app
  Rails::Command.invoke :application, ARGV
end
