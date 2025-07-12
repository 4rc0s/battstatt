#!/usr/bin/env ruby -w

require 'optparse'

# Default options
options = {
  verbose: false
}

# Parse command-line arguments
OptionParser.new do |opts|
  opts.banner = "Usage: battstatt.rb [options]"

  opts.on("-v", "--verbose", "Print detailed battery information") do |v|
    options[:verbose] = v
  end

  opts.on("--version", "Show version information") do
    puts "battstatt.rb 1.0.0"
    puts "Ruby: #{RUBY_DESCRIPTION}"
    exit
  end
end.parse!

# Execute ioreg to get battery details
begin
  ioreg_output = %x(/usr/sbin/ioreg -r -c AppleSmartBattery)
  if ioreg_output.empty?
    puts "Could not get battery information from ioreg."
    exit 1
  end
rescue
  puts "Unsupported system or could not execute ioreg."
  exit(1)
end

stats = {}
ioreg_output.scan(/"([^"]+)" = ([^\n]+)/).each do |match|
  key = match[0]
  value = match[1].strip
  stats[key] = value
end

# Define keys for the default, non-verbose output
DEFAULT_KEYS = [
  'CurrentCapacity',
  'CycleCount',
  'IsCharging',
  'TimeRemaining',
  'AvgTimeToFull',
  'Amperage',
  'Temperature'
]

# Keys to always skip, even in verbose mode
SKIP_KEYS = [
  'AbsoluteCapacity',
  'AppleRawAdapterDetails',
  'PackReserve',
  'CarrierMode',
  'ChargerConfiguration',
  'IOGeneralInterest',
  'IOReportLegend',
  'UpdateTime',
  'BootVoltage',
  'BatteryData',
  'KioskMode',
  'DeadBatteryBootData',
  'ManufacturerData',
  'FedDetails',
  'FullPathUpdated',
  'BatteryInvalidWakeSeconds',
  'ChargerData',
  'BootPathUpdated',
  'PowerTelemetryData',
  'PortControllerInfo',
  'UserVisiblePathUpdated',
  'IOReportLegendPublic',
  'AdapterDetails',
  'BatteryInstalled',
  'Location',
  'built-in'
]

puts
puts "-------------------------------"
puts "         Battery Stats"
puts "-------------------------------"
puts

# Determine which keys to display based on the verbose flag
keys_to_display = options[:verbose] ? stats.keys.sort : DEFAULT_KEYS

stats.sort.to_h.each do |k, v|
  next if SKIP_KEYS.include?(k)
  next unless keys_to_display.include?(k)

  display_v = ""
  if ['Amperage', 'InstantAmperage'].include?(k)
    amperage_val = v.to_i
    if amperage_val > 2**63 - 1
      amps = amperage_val - 2**64
    else
      amps = amperage_val
    end
    display_v = "#{amps} mA"
  elsif k.include?('Voltage')
    volts = v.to_f / 1000.0
    display_v = "#{sprintf("%.3f", volts)} V"
  elsif k.include?('Temperature')
    celsius = v.to_f / 100.0
    display_v = "#{sprintf("%.2f", celsius)} °C"
  elsif k.include?('Capacity')
    if ['CurrentCapacity', 'MaxCapacity', 'AbsoluteCapacity'].include?(k)
      display_v = "#{v} %"
    else
      display_v = "#{v} mAh"
    end
  elsif k.end_with?('Seconds')
    seconds = v.to_i
    if seconds >= 60
      display_v = "#{seconds / 60}m #{seconds % 60}s"
    else
      display_v = "#{seconds}s"
    end
  elsif ['TimeRemaining', 'AvgTimeToEmpty', 'AvgTimeToFull'].include?(k)
    minutes = v.to_i
    if minutes == 65535
      display_v = "N/A"
    elsif minutes > 0
      hours = minutes / 60
      remaining_minutes = minutes % 60
      display_v = "#{hours}h #{remaining_minutes}m"
    else
      display_v = "0m"
    end
  else
    display_v = v.gsub(/^"|"$/, '').gsub(/^{|}$/, '')
  end
  puts "#{k} => #{display_v}"
end

puts

# --- Summary Calculations ---
battery_data_str = stats['BatteryData']
design_capacity = nil
if battery_data_str
  match = battery_data_str.match(/"DesignCapacity"=(\d+)/)
  design_capacity = match[1].to_i if match
end

max_capacity = stats['NominalChargeCapacity']

if design_capacity && max_capacity
  percent_of_original = (max_capacity.to_f / design_capacity.to_f) * 100
  puts "Battery capacity is currently #{sprintf("%.2f", percent_of_original)}% of original."
else
  puts "Could not determine battery capacity."
end
