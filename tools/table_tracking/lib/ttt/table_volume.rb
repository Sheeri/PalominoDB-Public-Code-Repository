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
require 'ttt/table'

module TTT
  # Mapping to/from ttt.table_volumes table.
  # See ActiveRecord::Base for more information.
  class TableVolume < ActiveRecord::Base
    include TrackingTable
    self.collector= :volume

    after_create :update_cached_table_size

    # Returns the most recent size (in bytes) for 'server'
    def self.aggregate_by_server(server)
      self.server_size(server)
    end

    # Returns the most recent size (in bytes) for 'server'
    def self.server_size(server)
      s=self.server_sizes(server)
      if s.data_length.nil? or s.index_length.nil?
        nil
      else
        s.size
      end
    end

    def self.server_sizes0(server, time=:latest)
      s=self.server_sizes(server, time)
      if s.data_length.nil?
        s.data_length = 0
      end
      if s.index_length.nil?
        s.index_length = 0
      end
      s
    end

    def self.server_sizes(server, time=:latest)
      r=nil
      if time==:latest
        r=find_most_recent_versions({:conditions => ["server = ?", server]}, :latest)
      else
        r=find_most_recent_versions({:conditions => ["snapshots.run_time = ?  AND server = ?", time, server]})
      end
      raise Exception, "no rows returned" if r.length == 0
      d_length=0
      i_length=0
      r.each do |t|
        next if t.unreachable?
        d_length+=t.data_length
        i_length+=t.index_length
      end
      v=self.new(:server => server, :data_length => d_length == 0 ? nil : d_length, :index_length => i_length == 0 ? nil : i_length, :run_time => r[-1].nil? ? nil : r[-1].run_time)
      v.readonly!
      v
    end
    # Returns the most recent size (in bytes) for 'schema' on 'server'.
    def self.aggregate_by_schema(server,schema)
      self.database_size
    end
    # Returns the most recent size (in bytes) for 'schema' on 'server'.
    def self.database_size(server,database)
      self.database_sizes(server,database).size
    end
    def self.database_sizes0(server, database, time=:latest)
      s=self.database_sizes(server, database, time)
      if s.data_length.nil?
        s.data_length = 0
      end
      if s.index_length.nil?
        s.index_length = 0
      end
      s
    end
    # Returns the most recent size (in bytes) for 'schema' on 'server'.
    def self.database_sizes(server,database,time=:latest)
      r=nil
      if time==:latest
        r=find_most_recent_versions({:conditions => ["server = ?", server]}, :latest)
      else
        r=find_most_recent_versions({:conditions => ["snapshots.run_time = ? and server = ?", time, server]})
      end
      raise Exception, "no rows returned" if r.length == 0

      d_length=0
      i_length=0
      r.each do |t|
        next unless t.database_name == database
        next if t.unreachable?
        d_length+=t.data_length
        i_length+=t.index_length
      end
      v=self.new(:server => server, :database_name => database, :data_length => d_length == 0 ? nil : d_length, :index_length => i_length == 0 ? nil : i_length, :run_time => r[-1].run_time)
      v.readonly!
      v
    end

    def unreachable?
      database_name().nil? and table_name().nil? and data_length().nil? and index_length().nil? and data_free().nil?
    end

    def deleted?
      data_length().nil? and index_length().nil? and data_free().nil?
    end

    def tchanged?
      prev=previous_version
      if prev.nil?
        true
      else
        data_length != prev.data_length || index_length != prev.index_length
      end
    end

    def size
      unless data_length.nil? or index_length.nil?
        data_length+index_length
      else
        nil
      end
    end

    def self.create_unreachable_entry(host, runtime)
      self.new(
        :server => host,
        :database_name => nil,
        :table_name => nil,
        :data_free => nil,
        :index_length => nil,
        :data_length => nil,
        :run_time => runtime
      )
    end

    private
    def update_cached_table_size
      s=TTT::Server.find_by_name(server)
      if s
        sch=s.schemas.find_by_name(database_name)
        unless sch.nil?
          t=sch.tables.find_by_name(table_name)
          t.cached_size=size
          t.save
        end
      end
      true
    end

  end
end
