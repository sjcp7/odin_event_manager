require "csv"
require "google/apis/civicinfo_v2"
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, "0")[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir("output") unless Dir.exist? "output"

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_phonenumber(number)
  digits = number.tr('^0-9', '')
  bad_number = "0000000000"
  if digits.length < 10
    bad_number
  elsif digits.length == 11 && digits[0] == 1
    digits[1..digits.length]
  elsif digits.length == 11 && digits[0] != 1
    bad_number
  elsif digits.length > 11
    bad_number
  else
    digits
  end
end

def update_hours_hash(hash, hour)
  hash.has_key?(hour) ? hash[hour] += 1 : hash[hour] = 1
end

def update_weekdays_hash(hash, day)
  hash.has_key?(day) ? hash[day] += 1 : hash[day] = 1
end

def print_peak_hours(hours_hash)
  peak_hours = hours_hash.sort_by { |_, v| -v }
  puts "Peak Hours"
  peak_hours.each do |pair|
    hour = pair.first
    num_of_times = pair.last
    puts "#{hour}h | #{num_of_times} #{num_of_times == 1 ? "time" : "times"}"
  end
end

def print_peak_weekdays(weekdays_hash)
  peak_days = weekdays_hash.sort_by { |_, v| -v }
  puts "Peak Days"
  peak_days.each do |pair|
    day = pair.first
    num_of_times = pair.last
    puts "#{day} | #{num_of_times} #{num_of_times == 1 ? "time" : "times"}"
  end
end


puts "EventManager Initialized!"

contents = CSV.open "event_attendees.csv", headers: true, header_converters: :symbol

template_letter = File.read "form_letter.erb"
erb_template = ERB.new template_letter

hours_hash = {}
days_hash = {}

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  homephone = clean_phonenumber(row[:homephone])
  regdate = DateTime.strptime(row[:regdate], '%m/%d/%y %k:%M')
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)

  update_hours_hash(hours_hash, regdate.hour)
  update_weekdays_hash(days_hash, regdate.strftime("%A"))  

  save_thank_you_letter(id, form_letter)
  puts "#{name} #{homephone} #{regdate}"
end

print_peak_hours(hours_hash)
print_peak_weekdays(days_hash)
