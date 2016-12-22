require 'socket'
require 'thread'

module WEBrick

  module Utils
    #https://github.com/candlerb/webrick/blob/master/lib/webrick/utils.rb
    def create_listeners
      address='0.0.0.0'
      port=8081
      res = Socket::getaddrinfo(address, port, Socket::AF_UNSPEC, Socket::SOCK_STREAM, 0, Socket::AI_PASSIVE)
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
        run sock
        sock.close
      }
    end
  end

  #https://github.com/candlerb/webrick/blob/master/lib/webrick/httprequest.rb
  class HTTPRequest
    def parse(socket=nil)
      @request = socket.gets
      puts @request
    end
    def path
      '/'
    end
    def meta_vars
      nil
    end
    def method_missing(method_name)
      puts "missing #{method_name}"
      nil
    end
  end

  #https://github.com/candlerb/webrick/blob/master/lib/webrick/httpresponse.rb
  class HTTPResponse
    attr_reader :header, :body
    attr_accessor :status
    def initialize
      @status='200'
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
        #res.status= status.to_i
        #headers.each { |k, vs| res[k] = vs.split("\n").join(", ") }
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
      #@app ||= options[:builder] ? build_app_from_string : build_app_and_options_from_config
      @app ||= build_app_and_options_from_config
      #@app = Proc.new{|*args| ['200',[],["hello ","rails from app."]] }
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
end

#Rack::Server.start
module Rails

  def application
    @app = Proc.new{|*args| ['200',[],["hello ","rails from rails application."]] }
  end
  module_function :application

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

    class Base
    end

    #https://github.com/rails/rails/blob/master/railties/lib/rails/commands/server/server_command.rb
    class ServerCommand < Base
      def perform
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

end

#https://github.com/rails/rails/blob/master/railties/lib/rails/cli.rb
ARGV=['server']
Rails::Command.invoke :application, ARGV
