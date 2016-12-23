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
      @app = Proc.new{|*args| ['200',[],["hello ","rails from rails engine."]] }
      #@app ||= config.middleware.build(endpoint)
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
  end

  #https://github.com/rails/rails/blob/master/railties/lib/rails/application.rb
  class Application < Engine
    class << self
      def inherited(base)
        Rails.app_class = base
      end
    end
  end
  #can't find where the Application.inherited was called, temporary hard code here
  Application.inherited(Application)

end


module ActionDispatch
  class Request
    include Rack::Request::Env
    def initialize(env)
      super
    end
  end
end
