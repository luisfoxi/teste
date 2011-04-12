class AfterCreateCountries < ActiveRecord::Migration
  def self.up
    require 'open-uri'
    require 'yaml'
  
    execute <<-SQL
      CREATE LANGUAGE plpgsql;
    
      -- Function to validate strings hindering columns of tables will be empty
      -- Função para validar strings impedindo que colunas de tabelas fiquem vazias
      CREATE OR REPLACE FUNCTION STRING_NOT_EMPTY(texto VARCHAR)
        		RETURNS BOOLEAN AS
      $$
      BEGIN
        RETURN lpad(btrim(texto), 254) <> lpad(' ', 254) AND substring(texto, 1, 1) <> ' ';
      END
      $$
      LANGUAGE plpgsql;

      -- dm_name domain to be used in table columns that have mandatory
      -- Domínio db_nome para ser usado em colunas de tabela que tenham preenchimento obrigatório
      CREATE DOMAIN dm_name
		 	  AS VARCHAR(60)
        NOT NULL
        CHECK ( string_not_empty(VALUE) );

      -- Domain dm_timestamp for use with fields of the current date and time
      -- Domínio dm_timestamp para uso com campos de preenchimento da data e hora atual
      CREATE DOMAIN dm_timestamp
        AS timestamp with time zone
        DEFAULT now()
        NOT NULL;
      
      -- Altera o tipo do campo nome para o domínio db_nome
      ALTER TABLE countries ALTER COLUMN name TYPE dm_name;
  
      -- Add columns for audit
      -- Adiciona colunas para auditoria
      ALTER TABLE countries ADD COLUMN fg_active BOOLEAN DEFAULT true;
      ALTER TABLE countries ALTER COLUMN created_at TYPE dm_timestamp;
      ALTER TABLE countries ADD COLUMN created_by dm_name DEFAULT 'INDEFINIDO';
      ALTER TABLE countries ALTER COLUMN updated_at TYPE TIMESTAMP WITH TIME ZONE;
      ALTER TABLE countries ADD COLUMN updated_by VARCHAR(60);

      -- Create the audit table
      -- Cria a tabela de auditoria
      CREATE TABLE countries_audit (
  	    operation_audit char(1) NOT NULL,
        user_audit dm_name,
        datetime_audit dm_timestamp,
        LIKE countries
      );
  
  	  -- Create function for update columns for audit
  	  -- cria função para atualização de colunas para auditoria
      CREATE OR REPLACE FUNCTION countries_trigger() RETURNS trigger AS
      $$
      BEGIN
        IF (TG_OP = 'DELETE') THEN
  	      INSERT INTO countries_audit SELECT 'D', user, now(), OLD.*;
      	    RETURN OLD;
        ELSIF (TG_OP = 'UPDATE') THEN
          NEW.updated_at= now();
          INSERT INTO countries_audit SELECT 'U', user, now(), NEW.*;
            RETURN NEW;
        ELSIF (TG_OP = 'INSERT') THEN
          NEW.created_at= now();
          INSERT INTO countries_audit SELECT 'I', user, now(), NEW.*;
            RETURN NEW;
        END IF;
        RETURN NULL;
      END;
      $$
      LANGUAGE plpgsql;
  
  	  -- Function to prevent exclusion and modification of tuples in the audit table
  	  -- Função para impedir a exclusão e alteração de tuplas na tabela de auditoria
      CREATE OR REPLACE FUNCTION trigger_not_update() RETURNS trigger AS
   		$$
      BEGIN
        RAISE EXCEPTION 'Nao permitido fazer update ou delete em tabelas de auditoria!';
        RETURN NULL;
      END;
      $$
      LANGUAGE plpgsql;
  
  	  -- Add the trigger on the audit table
  	  -- Adiciona o trigger na tabela de auditoria
      CREATE TRIGGER trigger_not_update BEFORE UPDATE OR DELETE ON countries_audit
        FOR EACH ROW EXECUTE PROCEDURE trigger_not_update();
  
      -- Add the trigger on the countries table
      -- Adiciona o trigger na tabela countries
      CREATE TRIGGER countries_trigger BEFORE INSERT OR UPDATE OR DELETE  ON countries
        FOR EACH ROW EXECUTE PROCEDURE countries_trigger();

      ALTER SEQUENCE countries_id_seq
        INCREMENT 1000
        RESTART 1001;

    SQL
    puts "\n\nAtualizações SQL concluídas!"
    
    # Create countries from the list avaliable on Brazil's Central Bank site.
    # Inclui os paises a partir da lista disponível no site do Banco Central do Brasil.
    config = YAML.load_file('config/app_config.yml')
    source = config['source']
    country= source['country']
  
    uri = URI.parse(country) 
    open(uri) do |file|
      file.each_line do |linha|
        #puts linha
        if Country.find(:first, :conditions => { :bacen_code => linha[0..4] })==nil
          Country.create(:bacen_code=>linha[0..4], :name=>linha[6..55], :created_by=>'SISTEMA')
          puts "Created: #{linha}"
        end
      end
    end

  end

  def self.down
    Country.delete_all(:created_by=>'SISTEMA')

   	execute <<-SQL
		  DROP TRIGGER countries_trigger ON countries;
      DROP TRIGGER trigger_not_update ON countries_audit;
		  DROP FUNCTION trigger_not_update();
      DROP FUNCTION countries_trigger();
		
		  DROP TABLE countries_audit;
   
      -- Remove columns for audit
      -- Remove colunas para auditoria
      ALTER TABLE countries ALTER COLUMN created_at TYPE TIMESTAMP WITHOUT TIME ZONE;
      ALTER TABLE countries ALTER COLUMN updated_at TYPE TIMESTAMP WITHOUT TIME ZONE;
      ALTER TABLE countries DROP COLUMN updated_by;
      ALTER TABLE countries DROP COLUMN created_by;
      ALTER TABLE countries DROP COLUMN fg_active;
      
      -- Change type of column that have changed to db_name domain
      -- Altera o tipo do campo nome que havia sido alterado para o domínio db_name
      ALTER TABLE countries ALTER COLUMN name TYPE varchar(60);
   
      DROP DOMAIN dm_timestamp;
      DROP DOMAIN dm_name;
   		DROP FUNCTION STRING_NOT_EMPTY(texto VARCHAR);
   		DROP LANGUAGE plpgsql;
   	SQL
  end
end
