require 'sinatra'
require 'haml'

get '/optivis' do  
  haml :optivis
end

post '/run' do  
end

get '/' do  
  "Hello, World!"  
end

