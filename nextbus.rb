# encoding: utf-8
require 'rest-client'
require 'json'
require 'date'

# Static list of accepted directions to be given as an argument
ACCEPTED_DIRECTIONS = ['north', 'south', 'east', 'west']

# Use the metrotransit API to return a countdown in minutes and seconds
# for when the next bus departure is given a route, stop, and direction
def main
  validate_arguments
  route_id = route_id_from_desc(ARGV[0])
  direction_id = direction_id_from_route(ARGV[2], route_id)
  stop_id = stop_id_from_route(ARGV[1], route_id, direction_id)
  departure_info(route_id, direction_id, stop_id)
  puts difference_in_time(route_id, direction_id, stop_id)
end

# Use a GET call to get all route information in JSON and return as a hash
def route_info
  routes = RestClient.get('http://svc.metrotransit.org/NexTrip/Routes?format=json')
  JSON.parse(routes)
end

# Use a GET call to get all valid directions for a route in JSON and return as a hash
# @params route is the route ID (eg. 940)
def directions_info(route)
  directions = RestClient.get("http://svc.metrotransit.org/NexTrip/Directions/#{route}?format=json")
  JSON.parse(directions)
end

# Use a GET call to get all valid stop information for a route in JSON and return as a hash
# @params route - the route ID (eg. 940)
# @params direction - the direction ID (eg. 2)
def stop_info(route, direction)
  stops = RestClient.get("http://svc.metrotransit.org/NexTrip/Stops/#{route}/#{direction}?format=json")
  JSON.parse(stops)
end

# Use a GET call to return all valid departure information for a stop in JSON and return as a hash
# @params route - the route ID (eg. 940)
# @params direction - the direction ID (eg. 2)
# @params stop - the stop ID (eg.)
def departure_info(route, direction, stop)
  departures = RestClient.get("http://svc.metrotransit.org/NexTrip/#{route}/#{direction}/#{stop}?format=json")
  JSON.parse(departures)
end

# Determine if we're at a good starting point with the arguments that were given
def validate_arguments
  # Total number of arguments must 3
  raise 'Incorrect number of arguments given. Expecting 3 arguments' unless ARGV.length == 3
  # Last argument must be either 'north', 'south', 'east', or 'west' (not case sensitive)
  raise 'Invalid direction given. Must be either north, south, east, or west' unless ACCEPTED_DIRECTIONS.include?(ARGV[2].downcase)
end

# Find the route ID based on the route description substring
# @params desc - a substring of the description of a route (eg. 'State Fair - Ltd Stop - Minneapolis - State Fair')
def route_id_from_desc(desc)
  route_ids = []
  # Iterate through the route information retrieved from the API as a hash
  route_info.each do |info|
    # Only retrieve the route ID if the description includes the desc (not case sensitive)
    next unless info['Description'].downcase.include?(desc.downcase)
    route_ids.push(info['Route'])
  end
  # Raise an error if desc was too vague and resulted in multiple matches
  raise "Multiple Routes were found with description '#{desc}'." if route_ids.size > 1
  # Raise an error if there were no matches found
  raise "Route was not found with description '#{desc}'." if route_ids.empty?
  # Return the route ID
  route_ids[0]
end

# Find the direction ID based on the direction text and route id
# @params direction - direction text (eg. 'east')
# @params route - route ID (eg. 940)
def direction_id_from_route(direction, route)
  # Iterate through the direction information retrieved from the API as a hash
  directions_info(route).each do |info|
    # Only retrieve the direction ID if the direction text includes the direction (not case sensitive)
    next unless info['Text'].downcase.include?(direction.downcase)
    return info['Value']
  end
  # Raise an error if there were no matches found
  raise "Direction '#{direction}' was not found for route '#{route}'."
end

# Find the stop ID based on the route ID and direction ID
# @params stop - a substring of the description of a stop (eg. 'delasalle')
# @params route - the route ID (eg. 940)
# @params direction - the direction ID (eg. 2)
def stop_id_from_route(stop, route, direction)
  stop_ids = []
  # Iterate through the stop information retrieved from the API as a hash
  stop_info(route, direction).each do |info|
    # Only retrieve the stop ID if the stop text includes the stop description (not case sensitive)
    next unless info['Text'].downcase.include?(stop.downcase)
    stop_ids.push(info['Value'])
  end
  # Raise an error if stop was too vague and resulted in multiple matches
  raise "Multiple Stops were found with description '#{stop}'." if stop_ids.size > 1
  # Raise an error if there were no matches found
  raise "Stop '#{stop}' was not found for route '#{route}' in direction '#{direction}'." if stop_ids.empty?
  # Return the Stop ID
  stop_ids[0]
end

# Return earliest departure time in a DateTime format based on the route ID, direction ID, and stop ID
# @params route - the route ID (eg. 940)
# @params direction - the direction ID (eg. 2)
# @params stop - the stop ID (eg. 'FAIR')
def datetime_from_departure(route, direction, stop)
  # Get the departure information retrieved from the API as a hash
  info = departure_info(route, direction, stop)[0]
  # Raise an error if the last bus for the day has already left
  raise 'Last bus for the day has already left' if info.nil?
  # Strip the milliseconds and timezone from the departure time value
  stripped_time = info['DepartureTime'][/Date\((.*)\)/, 1]
  # Return the stripped time in a datetime format
  DateTime.strptime(stripped_time, '%Q %z')
end

# Return the minutes and seconds difference between the next departure point and the current datetime
# @params route - the route ID (eg. 940)
# @params direction - the direction ID (eg. 2)
# @params stop - the stop ID (eg. 'FAIR')
def difference_in_time(route, direction, stop)
  departure_time = datetime_from_departure(route, direction, stop)
  # Get the difference in seconds between the two dates
  difference = ((departure_time - DateTime.now) * 24 * 60 * 60).to_i
  # Calculate the minutes and seconds remaining
  minutes = difference / 60
  seconds = difference - minutes * 60
  # Return the difference in a string format
  "#{minutes} Minutes #{seconds} Seconds"
end

# Run program
main
