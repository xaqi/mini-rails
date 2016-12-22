require 'socket'
require 'thread'

module WEBrick

  module Utils
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

  class SimpleServer
    def SimpleServer.start
      yield
    end
  end

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

  class HTTPRequest
    def parse(socket=nil)
      @request = socket.gets
      puts @request
    end
    def path
      '/'
    end
  end

  class HTTPResponse
    def initialize(sock)
      @sock=sock
    end
    def send_response
      @sock << "HTTP/1.1 200/OK\r\nContent-type:text/html\r\n\r\n"
      @sock << 'hello rails.'
    end
  end

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

  class Server
    def self.start
      new.start
    end
    class << self
      def start &blk
        server.run &blk
      end
      def server
        @_server = Rack::Handler.default
      end
    end
  end

end

Rack::Server.start