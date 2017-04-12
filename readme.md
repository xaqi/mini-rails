mini-rails  
=====================
RubyChina讨论贴：<a href="https://ruby-china.org/topics/32764" target="_blank">https://ruby-china.org/topics/32764</a>

## What is mini-rails?

本想学习一下Rails源码，看看有什么magic；<br />
但源码文件太多，核心代码都淹没在大量细节实现中，全部看完不现实，走马观花又很难领会精髓； <br />
纸上得来终觉浅，眼过千遍，不如手过一遍，干脆重新造个轮子；<br />
于是就有了mini-rails，参照Rails源码，省略细节，实现了一个self-host mvc框架；<br />
再也不用对着庞大的Rails望洋兴叹了，600行代码为您还原一个真实的Rails；<br />

mini-rails实现了从socket到controller的层层封装，并注释了Rails源码中相应模块的位置，可作为学习Rails源码的目录或大纲；<br />
```
Socket -> WEBrick GenericServer -> WEBrick HTTPServer -> WEBrick HTTPServlet
-> Rack WEBrick -> Rack Handler -> Rack Server
-> Rails Server -> Engine -> Application -> Middleware -> ActionDispatch::Executor
-> MiddlewareStack -> Routing
-> Journey Router -> AbstractController -> Metal -> ActionController::Base
```

## How to run it?
```ruby
#运行test.rb，打开浏览器：
http://localhost:8081/Home/index        => "hello from Home Index."
http://localhost:8081/User/about        => "hello from User About."
http://localhost:8081/unkown_url        => "404"
```

## How to define a web page?
```ruby
require_relative 'mini-rails'

#define your controllers and actions
class UserController < ActionController::Base
    def about
        ['200',[],["hello from User About."]]
    end
end

start_server

```
