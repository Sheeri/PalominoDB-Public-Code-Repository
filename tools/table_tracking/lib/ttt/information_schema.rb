# Copyright (c) 2009-2010, PalominoDB, Inc.
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
#   * Redistributions of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
# 
#   * Redistributions in binary form must reproduce the above copyright notice,
#     this list of conditions and the following disclaimer in the documentation
#     and/or other materials provided with the distribution.
# 
#   * Neither the name of PalominoDB, Inc. nor the names of its contributors
#     may be used to endorse or promote products derived from this software
#     without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
require 'rubygems'
require 'active_record'

module TTT
  # Base class for connections to collection hosts.
  # Please see ActiveRecord for how these classes work.
  class InformationSchema < ActiveRecord::Base
    self.abstract_class = true
    @@connected_host=nil
    def self.connect(host, cfg)
      @@connected_host=host
      establish_connection( {
        "adapter" => "mysql",
        "host" => host,
        "database" => "information_schema",
        }.merge(cfg["dsn_connection"])
      )
      cfg['dsn_connection']['wait_timeout'] ||= 10000
      self.connection.execute("SET wait_timeout=" + cfg['dsn_connection']['wait_timeout'].to_s)
    end
    def self.get_connected_host
      @@connected_host
    end
    def self.find(*args) raise Exception, "Do not use information_schema." ; end
    private
    def establish_connection(*args)
      super(args)
    end
  end

  # Access to the "TABLES" table from information_schema database
  class TABLE < InformationSchema
    set_table_name :TABLES
    
    def self.get(schema,table)
      tables=find_by_sql("SHOW TABLE STATUS FROM `#{schema}` LIKE '%s'" % table)
      table_types={}
      connection.execute("SHOW FULL TABLES FROM `#{schema}` LIKE '%s'" % table).each do |tt|
        table_types[tt[0]] = tt[1]
      end
      tables.map! { |t| t[:table_type]=table_types[t.name] ;  t[:schema]=schema ; t.readonly! ; t }
      if tables.length == 1
        tables[0]
      else
        tables
      end
    end

    def self.all(*args)
      tables=[]
      connection.execute("SHOW DATABASES").each do |db|
        db=db[0]
        # Skip invalid database names, since, mysql apparently doesn't
        # prune 'bad' names for us.
        next if db.include? '.'
        tables<<get(db, '%')
      end
      tables.flatten!
    end

    def name
      self[:Name]
    end

    def table_type
      self[:table_type] ||= connection.execute("SHOW FULL TABLES FROM `#{schema}` LIKE '#{name}'").fetch_hash()['Table_type']
    end

    def schema
      self[:schema]
    end

    def engine
      self[:Engine]
    end

    def collation
      self[:Collation]
    end

    def comment
      self[:Comment]
    end

    def frm_version
      if self[:Version]
        self[:Version].to_i
      else
        nil
      end
    end

    def rows
      if self[:Rows]
        self[:Rows].to_i
      else
        nil
      end
    end

    def auto_increment
      if self[:Auto_increment]
        self[:Auto_increment].to_i
      else
        nil
      end
    end

    def update_time
      if self[:Update_time]
        self[:Update_time].to_time(:local)
      else
        nil
      end
    end

    def data_length
      if self[:Data_length]
        self[:Data_length].to_i
      else
        nil
      end
    end

    def index_length
      if self[:Index_length]
        self[:Index_length].to_i
      else
        nil
      end
    end

    def data_free
      if self[:Data_free]
        self[:Data_free].to_i
      else
        nil
      end
    end

    def max_data_length
      if self[:Max_data_length]
        self[:Max_data_length].to_i
      else
        nil
      end
    end

    def check_time
      if self[:Check_time]
        self[:Check_time].to_time(:local)
      else
        nil
      end
    end

    def create_time
      if self[:Create_time]
        self[:Create_time].to_time(:local)
      else
        nil
      end
    end

    def checksum
      self[:Checksum]
    end

    def avg_row_length
      if self[:Avg_row_length]
        self[:Avg_row_length].to_i
      else
        nil
      end
    end

    def row_format
      self[:Row_format]
    end

    def create_options
      self[:Create_options]
    end

    # Returns the table's data definition.
    # If the table is a regular table, then a statement
    # such as "CREATE TABLE.." will be returned.
    # If the table is a view, then a statement such as "CREATE VIEW.."
    # will be returned.
    def create_syntax
      syn=connection.execute("SHOW CREATE TABLE `#{schema}`.`#{name}`").fetch_hash()
      if table_type == "VIEW"
        syn["Create View"]
      else
        syn["Create Table"]
      end
    end
    # Returns true, if the table is determined to be a "system table".
    # That is, a table generated dynamically by MySQL.
    # Also appears to return true for views.
    def system_table?
      table_type == "SYSTEM VIEW" or (create_options !~ /partitioned/ and create_time.nil? and update_time.nil?)
    end
  end

end

