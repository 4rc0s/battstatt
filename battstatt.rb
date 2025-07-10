#!/usr/bin/env ruby -w

# Execute ioreg to get battery details. The -r flag provides a more stable,
# non-XML output that is easier to parse reliably.
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
# This regex is designed to parse the key-value structure of the ioreg output,
# including nested data structures like "BatteryData" = {...}
ioreg_output.scan(/"([^"]+)" = ([^\n]+)/).each do |match|
  key = match[0]
  value = match[1].strip
  stats[key] = value
end

# Define a list of keys to skip in the detailed output because they are
# too verbose or not relevant for a quick summary.
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
  'BatteryData', # Parsed for summary, but too verbose to print raw.
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
  'AdapterDetails'
]

puts
puts "-------------------------------"
puts "         Battery Stats"
puts "-------------------------------"
puts

# Print all the gathered stats in a clean, readable format,
# skipping the keys defined in SKIP_KEYS.
stats.sort.to_h.each do |k, v|
  next if SKIP_KEYS.include?(k)

  display_v = ""
  # Special handling for amperage fields to make them human-readable.
  if ['Amperage', 'InstantAmperage'].include?(k)
    amperage_val = v.to_i
    # Convert 64-bit unsigned to signed.
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
    # Handle percentage vs. mAh units for different capacity fields.
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
      display_v = "Not Charging"
    elsif minutes > 0
      hours = minutes / 60
      remaining_minutes = minutes % 60
      display_v = "#{hours}h #{remaining_minutes}m"
    else
      display_v = "0m"
    end
  else
    # Clean up the value for better display.
    # Remove surrounding quotes from strings and braces from dictionaries.
    display_v = v.gsub(/^"|"$/, '').gsub(/^{|}$/, '')
  end
  puts "#{k} => #{display_v}"
end

puts

# --- Summary Calculations ---

# Extract DesignCapacity from the nested BatteryData string.
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
