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
  end

  class HTTPResponse
    def send_response(socket)
      socket << "HTTP/1.1 200/OK\r\nContent-type:text/html\r\n\r\n"
      socket << 'hello rails.'
    end
  end

  class HTTPServer < GenericServer
    def run(socket)
      req=HTTPRequest.new
      res=HTTPResponse.new
      req.parse socket
      res.send_response socket
    end
  end

end

WEBrick::HTTPServer.new.start