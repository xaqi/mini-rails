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
  end

  #https://github.com/candlerb/webrick/blob/master/lib/webrick/httpresponse.rb
  class HTTPResponse
    def initialize(sock)
      @sock=sock
    end
    def send_response
      @sock << "HTTP/1.1 200/OK\r\nContent-type:text/html\r\n\r\n"
      @sock << 'hello rails.'
    end
  end

  #https://github.com/candlerb/webrick/blob/master/lib/webrick/httpserver.rb
  class HTTPServer < GenericServer
    def initialize
      @mount_tab = Hash.new
    end
    def run(socket)
      req=HTTPRequest.new
      res=HTTPResponse.new socket
      req.parse socket
      self.service(req, res)
      socket.close
    end
    def service(req, res)
      servlet, = search_servlet req.path
      si = servlet.get_instance self
      si.service req, res
    end
    def search_servlet(path)
      @mount_tab[path]
    end
    def mount(dir,servlet)
      @mount_tab[dir] = [servlet]
    end
  end

end

#WEBrick::HTTPServer.new.start

module WEBrick
  module HTTPServlet

    #https://github.com/candlerb/webrick/blob/master/lib/webrick/httpservlet/abstract.rb
    class AbstractServlet
      def initialize(server)
        @server = server
      end
      def self.get_instance(server)
        self.new server
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
      def self.run
        @server = ::WEBrick::HTTPServer.new
        @server.mount '/',Rack::Handler::WEBrick
        @server.start
      end
      def service(req, res)
        res.send_response
      end
    end

  end

  #https://github.com/rack/rack/blob/master/lib/rack/server.rb
  class Server
    def self.start
      new.start
    end
    def start &blk
      server.run &blk
    end
    def server
      @_server = Rack::Handler.default
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
