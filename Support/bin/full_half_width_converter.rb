#!/usr/bin/env ruby
# Converts between half width and full width forms through lib/HanZenKaku.txt,
# whose rows are the half width form and its full width form.
#
#   full_half_width_converter.rb toFull|toHalf < text

direction = ARGV.first
unless %w[toFull toHalf].include?(direction)
  puts "Wrong argument. Only 'toFull' or 'toHalf'."
  exit 206
end

STDIN.set_encoding("UTF-8")
table = File.join(ENV.fetch("TM_BUNDLE_SUPPORT"), "lib", "HanZenKaku.txt")

conversions = {}
File.foreach(table, encoding: "UTF-8") do |row|
  half, full = row.chomp.split("\t")
  next unless half && full
  if direction == "toFull"
    conversions[half] = full
  else
    conversions[full] = half
  end
end

if conversions.empty?
  puts "File error for HanZenKaku.txt"
  exit 206
end

STDIN.read.each_char { |c| print conversions.fetch(c, c) }
exit 201
