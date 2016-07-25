require 'json'
require 'mongo_mapper'
require 'sidekiq'
require 'sinatra'
require 'pry'
require 'sidekiq/api'
require 'abanalyzer'
require 'rubystats'
require 'bcrypt'
require 'pony'
require 'tf-idf-similarity'
require 'cld'
require 'narray'
require 'pickup'
Dir[File.dirname(__FILE__) + '/extensions/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }
MongoMapper::Document.plugin(RandomField)
Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/helpers/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/handlers/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/before_hooks/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/tasks/*.rb'].each {|file| require file }
set :erb, :layout => :'layouts/main'
set :bind, '0.0.0.0'
set :environment, :production
enable :sessions
#register Sinatra::Flash

helpers LayoutHelper

MongoMapper.connection = Mongo::MongoClient.new("localhost", 27017, :pool_size => 25, :op_timeout => 60, :timeout => 60, :pool_timeout => 60)
MongoMapper.database = "cyrano"
