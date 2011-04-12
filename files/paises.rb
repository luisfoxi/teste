require 'open-uri' 
require "yaml"

config = YAML.load_file('../config/app_config.yml')

source = config['source']

country= source['country']
  
uri = URI.parse(country) 
open(uri) do |file|
  file.each_line do |linha|
    puts "\nCreated: #{linha}"
  end
#  puts file.read() 
end 

#    File.open('http://www.bcb.gov.br/rex/ftp/paises.txt', 'r') do |f1|
#      while linha = f1.gets  
#        puts "\nCreated: #{linha}"
#      end
#    end      

