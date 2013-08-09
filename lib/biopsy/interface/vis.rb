require 'sinatra'

get '/optivis' do  
  puts "you said #{params[:message]}" if params.has_key? :message
  erb :optivis
end

post '/run' do  
end

get '/' do  
  "Hello, World!"  
end

