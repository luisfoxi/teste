class CreateCountries < ActiveRecord::Migration
  def self.up
    create_table :countries do |t|
      t.string :bacen_code,   :limit=>5,    :null=>false,   :unique=>true
      t.string :name,         :limit=>60,   :null=>false,   :unique=>true
      
      t.timestamps
    end
  end
  
  def self.down
    drop_table :countries
  end
end

