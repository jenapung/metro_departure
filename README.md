## Introduction
The program nextbus.rb utilizes the metro transit API (http://svc.metrotransit.org/) to calculate the remaining minutes and seconds left from now until the next bus departure. <br />
It does this by taking in three arguments. The first argument must be a substring of the bus route description. The second argument must be a substring of the bus stop description. <br />
The third argument must be a direction (north, south, east, or west). All arguments are case insensitive.

## Installation and Execution
Refer to the Gemfile for a list of the Ruby version and gems needed for this program. At a minimum, Ruby 2.3.1 with gems rest-client, date, and json are needed.<br />
While in the root of the project use 'ruby nextbus.rb' + the three arguments to run the program. <br />
Example: `ruby nextbus.rb 'State Fair - Ltd Stop - Minneapolis - State Fair' 'delasalle' 'east'`

## Code Walk-through
We begin by performing basic validations on the arguments that were passed in. Errors are raised if one of the one of the following criteria are not met:
* There must be exactly 3 arguments
* The third argument must be either 'north', south', 'east', or 'west'
```
# Determine if we're at a good starting point with the arguments that were given
def validate_arguments
  # Total number of arguments must 3
  raise 'Incorrect number of arguments given. Expecting 3 arguments' unless ARGV.length == 3
  # First two arguments must be strings
  raise 'Route argument must be given as a string' unless ARGV[0].is_a?(String)
  raise 'Stop argument must be given as a string' unless ARGV[1].is_a?(String)
  # Last argument must be either 'north', 'south', 'east', or 'west' (not case sensitive)
  raise 'Invalid direction given. Must be either north, south, east, or west' unless ACCEPTED_DIRECTIONS.include?(ARGV[2].downcase)
end
```
The API GET calls needed are split out into their own methods and data is always returned as a hash. The following API calls are performed:
* GetRoutes - The route ID is needed in order to perform other API calls. Since we are only given a substring description of the route then we need to find the corresponding ID via this API call.
* GetDirections - The direction ID is needed in order to perform other API calls. Since we are only given the direction text then we need to find the corresponding ID via this API call. <br />The route ID we retrieved through the GetRoutes call is used for this API call.
* GetStops - The stop ID is needed in order to perform other API calls. Since we are only given a substring description of the stop then we need to find the corresponding ID via this API call. <br />The route ID we retrieved through the GetRoutes call and the direction ID we retrieved through the GetDirections call are used for this API call.
* GetTimepointDepartures - The next departure datetime is needed in order to calculate the difference from the current datetime. <br />The route ID we retrieved through the GetRoutes call, the direction ID we retrieved through the GetDirections call, and the stop ID we retrieved from the GetStops call are all used for this API call.<br />

Example:
```
# Use a GET call to return all valid departure information for a stop in JSON and return as a hash
# @params route - the route ID (eg. 940)
# @params direction - the direction ID (eg. 2)
# @params stop - the stop ID (eg.)
def departure_info(route, direction, stop)
 departures = RestClient.get("http://svc.metrotransit.org/NexTrip/#{route}/#{direction}/#{stop}?format=json")
 JSON.parse(departures)
end
```
As mentioned previously, it was necessary to extrapolate the system IDs of the arguments from the user friendly descriptions that were given in order to use the IDs for the time departure API call.<br />
This was done by using the API calls to match the description to an entry and return it's ID. An error is raised if the description given is not unique enough to return only 1 match or if no matches are returned. <br />
<br />
Example:
```
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
```
Once we are able to make the departure time API call we need to take the datetime value (in milliseconds) for the departure and convert it to a datetime format. <br />
This was done using regexp to only retrieve the milliseconds value encapsulated in the 'Date()' string and then use strptime to convert it from milliseconds into a datetime format.
<br />
```
# Return earliest departure time in a DateTime format based on the route ID, direction ID, and stop ID
# @params route - the route ID (eg. 940)
# @params direction - the direction ID (eg. 2)
# @params stop - the stop ID (eg. 'FAIR')
def datetime_from_departure(route, direction, stop)
  # Get the departure information retrieved from the API as a hash
  info = departure_info(route, direction, stop)[0]
  # Strip the milliseconds and timezone from the departure time value
  stripped_time = info['DepartureTime'][/Date\((.*)\)/, 1]
  # Return the stripped time in a datetime format
  DateTime.strptime(stripped_time, '%Q %z')
end
```
Now that we have the next departure time in a datetime format we can get the difference between then and the current datetime. <br />
I calculated the difference in seconds, then got minutes by dividing the seconds by 60, and then got the remaining seconds by taking the difference of the seconds and minutes and multiplied by 60. A string is returned that contains the minutes and seconds.
<br />
```
# Return the minutes and seconds difference between the next departure point and the current datetime
# @params route - the route ID (eg. 940)
# @params direction - the direction ID (eg. 2)
# @params stop - the stop ID (eg. 'FAIR')
def difference_in_time(route, direction, stop)
  departure_time = datetime_from_departure(route, direction, stop)
  # Raise an error if the last bus for the day has already left
  raise 'Last bus for the day has already left' unless Date.today.day == departure_time.day
  # Get the difference in seconds between the two dates
  difference = ((departure_time - DateTime.now) * 24 * 60 * 60).to_i
  # Calculate the minutes and seconds remaining
  minutes = difference / 60
  seconds = difference - minutes * 60
  # Return the difference in a string format
  "#{minutes} Minutes #{seconds} Seconds"
end
```
Finally, we output that string that contains the minutes and seconds as part of the main method via a puts command
```
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
```
