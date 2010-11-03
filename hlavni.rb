require 'rubygems'
require 'sinatra'
require 'logger'
require 'datamapper'
require 'haml'
require 'sass'
require 'dm-mysql-adapter'
require 'rack-flash'

require 'sinatra/reloader' if development?
require 'modules/before_only.rb'

enable :sessions
use Rack::Flash
use Rack::MethodOverride # for DELETE and PUT.

configure do
  set :app_file, __FILE__
  set :root, File.dirname(__FILE__)
  set :static, :true
  set :public, Proc.new { File.join(root, "public") }
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
  belongs_to :subfam, :required => false
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
  has n, :druh_common_names, :through => Resource
  belongs_to :gen, :required => false
end

class DruhImg
  include DataMapper::Resource

  property :id, Serial
  property :img_link, String, :required => true
  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :druh, :required => false
end

class DruhCommonName
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :required => true
  property :created_at, DateTime
  property :updated_at, DateTime

  has n, :druhs, :through => Resource
end

# Filters

before_only_re '\/(home|admin|browse)\/.+' do
  @sidebar = "_" + params[:capture][0] + "_sidebar"
end

# Routes

get '/mustelid.css' do
  headers 'Content-Type' => 'text/css; charset=utf-8'
  sass :"sass/mustelid"
end

get '/admin/*/new' do
  @link = params['splat'][0]
  @var = link_assoc[params['splat'][0]]
  haml :"admin/#{@link}/new"
end

get '/admin/*/:id' do
  @link = params['splat'][0]
  @var = link_assoc[@link]
  logger.info "Going to edit page - @link -> " + @link + ", params -> " + params['id']
  @model = Object::const_get(@var.capitalize).get(params['id'].to_i)
  haml :"admin/#{params['splat'][0]}/edit"
end

get '/admin/*' do
  @link = params['splat'][0]
  @var = link_assoc[@link]
  if Subfam.count == 0
    flash[:notice] = "There are no subfamilies."
    redirect "/admin/subfamily/new"
  elsif Gen.count == 0 && (@var == "gen" || @var == "druh")
    flash[:notice] = "There are no genuses."
    redirect "/admin/genus/new"
  elsif Druh.count == 0 && (@var == "druh")
    flash[:notice] = "There are no species."
    redirect "/admin/species/new"
  end
  eval("@#{@var}s = #{@var.capitalize}.all")
  haml :"admin/#{params['splat'][0]}/index"
end

post '/admin/*' do # I think that this and the update method can be refactored.
  @link = params['splat'][0]
  @var = link_assoc[@link]
  model = Object::const_get(@var.capitalize).new
  if @var == "druh"
    gen = Gen.get(params['druh'].delete("gen_id").to_i)
    common_names = params['druh'].delete("common_names")
    gen.druhs << model
  end
  if @var == "gen"
    subfam = Subfam.get(params['gen'].delete("subfam_id").to_i)
    subfam.gens << model
  end

  model.attributes = params[@var]
  unless model.save
    flash[:notice] = unroll(model.errors)
    redirect "/admin/#{@link}/new"
  else
    if @var == "druh"
      set_common_names(model, common_names)
    end
    flash[:notice] = "Created!"
    redirect "/admin/#{@link}"
  end
end

put '/admin/*/:id' do # I think this can be refactored w/ create.
  @link = params['splat'][0]
  @var = link_assoc[@link]
  model = Object::const_get(@var.capitalize).get(params['id'].to_i)
  if @var == "druh"
    common_names = params['druh'].delete("common_names")
    new_gen_id = params['druh'].delete("gen_id").to_i
    unless new_gen_id == model.gen.id
      old_gen = model.gen
      old_gen.druhs.delete_at(old_gen.druhs.index(model)) # this sucks, vole.
      new_gen = Gen.get(new_gen_id)
      new_gen.druhs << model
      new_gen.save # I should check if this fails.
    end
  end
  if @var == "gen"
    new_subfam_id = params['gen'].delete("subfam_id").to_i
    unless new_subfam_id == model.subfam.id
      old_subfam = model.subfam
      old_subfam.gens.delete_at(old_subfam.gens.index(model)) # this sucks!
      new_subfam = Subfam.get(new_subfam_id)
      new_subfam.gens << model
      new_subfam.save
    end
  end
  
  unless model.update(params[@var])
    flash[:notice] = unroll(model.errors)
    redirect "/admin/#{@link}/#{params['id']}"
  else
    if @var == "druh"
      set_common_names(model, common_names)
    end
    flash[:notice] = "Updated!"
    redirect "/admin/#{@link}"
  end
end

delete '/admin/*/:id' do
  @link = params['splat'][0]
  @var = link_assoc[@link]
#  logger.info "delete ... link: #{@link}  var: #{@var}  id: #{params['id']}"
  deleted = Object::const_get(@var.capitalize).get(params['id'].to_i).destroy
  flash[:notice] = deleted ? "Deleted!" : "Deletion failed."
  redirect "/admin/#{@link}"
end

# Ajax routes

get '/ajax/changeGenus/:subfam' do
  haml :"partials/_genus", :locals => { :subfam => params['subfam'] }, :layout => false
end

# Mockup

get '/mock/:file' do
  haml :"mock/#{params['file']}", :layout => false
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

helpers do
  def haml_partial(name, options = {})
    item_name = name.to_sym
    counter_name = "#{name}_counter".to_sym
    if collection = options.delete(:collection)
      collection.enum_for(:each_with_index).collect do |item,index|
        haml_partial name, options.merge(:locals => {item_name => item, counter_name => index+1})
      end.join
    elsif object = options.delete(:object)
      haml_partial name, options.merge(:locals => {item_name => object, counter_name => nil})
    else
      haml "#{name}".to_sym, options.merge(:layout => false)
    end
  end
end

# the common names thang.
helpers do
  def set_common_names(model, common_names)
    model.druh_common_names.clear
    common_names.split(/,/).each do |cn|
      logger.info "Common name: " + cn
      cn.strip!
      cn.downcase!
      cn_object = DruhCommonName.first(:name => cn) || DruhCommonName.create(:name => cn)
      unless model.druh_common_names.include? cn_object
        model.druh_common_names << cn_object
      end
    end
    model.save
  end
end

# options is an array of [value, text] entries for options.
helpers do
  def options_for_select(selected, options)
    options.sort.inject([]) { |opts, opt|
      opts << ("<option value=\"#{opt[0]}\"" + (opt[0] == selected ? " selected=\"true\"" : "") + ">#{opt[1]}</option>")
    }.join
  end
end

# These are all for making options collections.
helpers do
  def extract_id_name(objs)
    objs.inject([]) { |kvs, obj|
      kvs << [ obj.id, obj.name ]
    }
  end

  def get_subfamilies
    extract_id_name(Subfam.all)
  end

  def get_genuses(subfam_id = nil)
    if subfam_id.nil?
      extract_id_name(Gen.all)
    else
      extract_id_name(Subfam.get(subfam_id).gens)
    end
  end

  def get_species(gen_id = nil)
    if gen_id.nil?
      extract_id_name(Druh.all)
    else
      extract_id_name(Druh.all(:gen_id => gen_id))
    end
  end
end
