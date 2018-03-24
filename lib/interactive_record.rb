require_relative "../config/environment.rb"
require 'active_support/inflector'
require 'pry'

class InteractiveRecord

  def initialize(hash = {})
    hash.each do |k, v|
      self.send("#{k}=", v)
    end
  end

  def self.table_name
    self.to_s.downcase.pluralize
  end

  def table_name_for_insert
    self.class.table_name
  end

  def placeholders_for_insert
    less_id.map { '?' }.join(', ')
  end

  def less_id
    self.class.column_names.reject { |name| name == 'id' }
  end

  def col_names_for_insert
    less_id.join(', ')
  end

  def self.column_names
    DB[:conn].execute("pragma table_info('#{table_name}')").map { |a| a[1] }
  end

  def attributes
    less_id.map { |attr| self.send(attr) }
  end

  def values_for_insert
    attributes.map {|a| "'#{a}'" }.join(", ")
  end

  def save
    if id.nil? # what to do if id is not a column? (see activerecord::base#persisted?)
      sql = <<-SQL
      INSERT INTO #{table_name_for_insert}(#{col_names_for_insert})
      VALUES (#{placeholders_for_insert})
      SQL
      DB[:conn].execute(sql, *attributes)
      @id = DB[:conn].last_insert_row_id
      self
    else
      sql = <<-SQL
      UPDATE #{self.class.table_name}
      SET #{self.class.column_names.join('= ?, ')}
      WHERE id = ?
      SQL
      DB[:conn].execute(sql, *attributes, id)
      self
    end
  end

  def self.where(hash)
    sql = "SELECT * FROM #{table_name} WHERE #{hash.keys.join('= ?, ')} = ?"
    puts sql
    DB[:conn]
    .execute(sql, *hash.values)
  end

  def self.where_instances(hash)
    where(hash).map { |row| self.new(row.slice(self.column_names)) }
  end
  def self.find_by(hash)
    self.where(hash)
  end

  def self.inherited(child)
    child.column_names.each do |name|
      attr_accessor name.to_sym
      child.define_singleton_method("find_by_#{name}") { |x| self.find_by({name => x}) }
    end
  end
end
