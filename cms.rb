require 'sinatra'
require "sinatra/reloader" if development?
require 'tilt/erubis'
require "redcarpet"

enable :sessions
root = File.expand_path("..", __FILE__)

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
      render_markdown(content)
    end
  end
end

get '/' do
  @files = Dir.glob(root + "/data/*").map {|file| File.basename(file)}
  erb :index
end

get "/:filename" do
  path = root + "/data/" + params[:filename]
  if File.exist?(path)
    load_file_content(path)
  else
    session[:error] = "The specified file was not found."
    redirect "/"
  end
end
