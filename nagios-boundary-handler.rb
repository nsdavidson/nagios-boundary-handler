#!/usr/bin/env ruby

require 'boundary_event'
require 'optparse'
require 'yaml'

BOUNDARY_CREDS_FILE = "boundary.yml"

def load_creds(file)
	begin
		creds = YAML.load_file(file)
	rescue
		return {}
	end

	if creds.key?("apikey") && creds.key?("orgid")
		return creds
	else
		return {}
	end
end

boundary_creds = load_creds(BOUNDARY_CREDS_FILE)

options = {}

OptionParser.new do |opts|
	opts.on("-H", "--hostname HOSTNAME", "Hostname") { |h| options[:hostname] = h }
	opts.on("-e", "--event-type TYPE", [:host, :service], "Event type") { |e| options[:event_type] = e }
	opts.on("-s", "--state STATE", "Event state") { |s| options[:state] = s }
	opts.on("-t", "--state-type", [:HARD, :SOFT], "Event state type") { |t| options[:state_type] = t }
	opts.on("-a", "--attempts ATTEMPTS", OptionParser::DecimalInteger, "Event attempts") { |a| options[:attempts] = a }
	opts.on("-o", "--output OUTPUT", "Check output") { |o| options[:output] = o }
	opts.on("-d", "--description DESC", "Service description") { |d| options[:service_description] = d }
	opts.on_tail("-h", "--help", "Show this message") do
		puts opts
		exit
	end

	begin
		opts.parse!

		# Required flags
		required = [:hostname, :state, :state_type, :attempts, :output, :event_type]
		missing = required.select { |f| options[f].nil? }
		unless missing.empty?
			raise OptionParser::ParseError, "Missing flag(s):" + missing.collect{|o| "--" + o.to_s.gsub(/_/, "-")}.join(" ")
		end

		if options[:event_type] == "service"
			if options[:description].nil?
				raise OptionParser::ParseError, "Missing flag(s) --description"
			end
		else
			options[:description] = nil
		end
	rescue OptionParser::ParseError
		$stderr.print "Error: #{$!}\n"

		puts
		puts opts
		exit 1
	end
end

event = BoundaryEvent.new(:api_key => boundary_creds["apikey"], :org_id => boundary_creds["orgid"])
title = "#{options[:hostname]} - #{options[:description]}"
properties = { :eventKey => "nagios-check", :state => "#{options[:state]}", :attempts => options[:attempts], :host => options[:hostname]}
message = "#{options[:output]}"
fingerprint = ["eventKey", "@title", "host"]
source = { :ref => "#{options[:hostname]}", :type => "#{options[:event_type]}"}
tags = ["#{options[:hostname]}"]

event.populate_event(:title => title, :properties => properties, :message => message, :fingerprint_fields => fingerprint, :source => source, :tags => tags)
event.send_event



