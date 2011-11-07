#!/usr/bin/env ruby -wKU
res = Array.new
begin
  rawstring = %x(/usr/sbin/ioreg -l | grep -i 'AppleSmartBattery ' -A 36)
  res = rawstring.to_a[2..-2]
rescue
  puts "Unsupported system."
  exit(1)
end

stats = Hash.new

res.each do |d| 
  key, val = d.split("=", 2)
  key.delete!(" ")
  if key =~ /\"(.*)\"/
    key = $1
  end
  stats[:"#{key}"] = val
end

puts
puts "-------------------------------"
puts "         Battery Stats"
puts "-------------------------------"
puts
stats.each { |k, v| puts "#{k} => #{v}" }
percentOfOriginal = (stats[:MaxCapacity].to_f / stats[:DesignCapacity].to_f) * 100
puts "Battery capacity is currently #{sprintf("%.2f", percentOfOriginal)}% of original."
amps = (stats[:Amperage].to_i + 2**15) % 2**16 - 2**15 # convert to signed 16-bit integer 
puts "Amperage is #{amps} mA."