require 'rubygems'
require 'sinatra'
require 'logger'
require 'datamapper'
require 'haml'
require 'dm-mysql-adapter'
require 'rack-flash'

enable :sessions
use Rack::Flash

configure do
  LOGGER = Logger.new("mustelid.log") 
end
 
link_assoc = { "subfamily" => "subfam",
  "genus" => "gen",
  "species" => "druh" }

DataMapper.setup(:default, 'mysql://localhost/mustelid')

# Models.

class Subfam
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true, :unique => true
  property :description, Text
  property :created_at, DateTime
  property :updated_at, DateTime

  has n, :gens
end

class Gen
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true, :unique => true
  property :description, Text
  property :created_at, DateTime
  property :updated_at, DateTime

  has n, :druhs
  belongs_to :subfam
end

class Druh # Species (in Czech, since 'Spec' is not good)
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true, :unique => true
  property :description, Text
  property :img_link, String
  property :created_at, DateTime
  property :updated_at, DateTime

  has n, :druh_imgs
  belongs_to :gen
end

class DruhImg
  include DataMapper::Resource

  property :id, Serial
  property :img_link, String, :required => true
  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :druh
end

get '/admin/*/new' do
  @link = params['splat'][0]
  @var = link_assoc[params['splat'][0]]
  haml :"admin/#{@link}/new"
end

get '/admin/*/:id' do
  var = link_assoc[params['splat'][0]]
  eval("@#{var} = #{var.capitalize}.first(params['id'])")
  haml :"admin/#{params['splat'][0]}/edit"
end

get '/admin/*' do
  var = link_assoc[params['splat'][0]]
  eval("@#{var}s = #{var.capitalize}.all")
  haml :"admin/#{params['splat'][0]}/index"
end

post '/admin/*' do
  link = params['splat'][0]
  var = link_assoc[link]
  model = Object::const_get(var.capitalize).new
  model.attributes = params[var]
  unless model.save
    flash[:notice] = unroll(model.errors)
    redirect "/admin/#{link}/new"
  else
    flash[:notice] = "Created!"
    redirect "/admin/#{link}"
  end
end

# Helpers

helpers do
  def logger
    LOGGER
  end

  def unroll(hash)
    hash.values.join('\n')
  end
end

# Render the page once:
# Usage: partial :foo
# 
# foo will be rendered once for each element in the array, passing in a local variable named "foo"
# Usage: partial :foo, :collection => @my_foos    

helpers do
  def partial(template, *args)
    options = args.extract_options!
    options.merge!(:layout => false)
    if collection = options.delete(:collection) then
      collection.inject([]) do |buffer, member|
        buffer << haml(template, options.merge(
                                  :layout => false, 
                                               :locals => {template.to_sym => member}
                                )
                     )
      end.join("\n")
    else
      haml(template, options)
    end
  end
end
