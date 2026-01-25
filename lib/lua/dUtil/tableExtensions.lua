local hasResty, result = pcall(require, 'table.isempty')
if hasResty then
  table.isempty = result
  table.isarray = require 'table.isarray'
  table.nkeys = require 'table.nkeys'
  table.clone = require 'table.clone'
end

table.new = require 'table.new'
