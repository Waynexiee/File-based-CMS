require 'sinatra'
require "sinatra/reloader" if development?
require 'tilt/erubis'
require "redcarpet"
require "yaml"
require "bcrypt"

enable :sessions
root = File.expand_path("..", __FILE__)

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def user_signed_in?
  session.key?(:username)
end

def require_signed_in_user
  unless user_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

before do
  session[:filename] ||= []
end

helpers do
  def render_markdown(text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(text)
  end

  def load_file_content(path)
    content = File.read(path)
    case File.extname(path)
    when ".txt"
      headers["Content-Type"] = "text/plain"
      content
    when ".md"
      erb render_markdown(content)
    end
  end
end

get '/' do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map {|file| File.basename(file)}
  erb :index
end


get "/new" do
  require_signed_in_user
  erb :new
end

post "/new" do
  require_signed_in_user
  filename = params[:new_file].to_s
  if filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  else
    path = File.join(data_path,filename)
    File.write(path,"")
    session[:message] = "#{params[:new_file]} has been created."
    redirect "/"
  end
end

get "/users/signin" do
  erb :sign
end

post "/users/signin" do
  credentials = load_user_credentials
  username = params[:username]
  password = params[:password]
  if valid_credentials?(username, password)
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :sign
  end
end

post "/users/signout" do
  session[:username] = nil
  session[:message] = "You have been signed out."
  redirect "/"
end

get "/:filename" do
  path = File.join(data_path, params[:filename])
  if File.exist?(path)
    load_file_content(path)
  else
    session[:message] = "The specified file was not found."
    redirect "/"
  end
end

get "/:filename/edit" do
  require_signed_in_user
  path = File.join(data_path, params[:filename])
  @content = File.read(path)
  @filename = params[:filename]
  erb :edit
end

post "/:filename" do
  require_signed_in_user
  path = File.join(data_path, params[:filename])
  File.open(path, 'w') { |file| file.write(params[:content]) }
  session[:message] = "#{params[:filename]} has been updated!"
  redirect '/'
end

post "/:filename/delete" do
  require_signed_in_user
  path = File.join(data_path, params[:filename])
  File.delete(path)
  session[:message] = "#{params[:filename]} has been deleted!"
  redirect '/'
end
