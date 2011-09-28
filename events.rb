##
# In this file you can define callbacks for different aspects of the framework. Below is an example:
##
#
# events.asterisk.before_call.each do |call|
#   # This simply logs the extension for all calls going through this Adhearsion app.
#   extension = call.variables[:extension]
#   ahn_log "Got a new call with extension #{extension}"
# end
#
##
# Asterisk Manager Interface example:
#
# events.asterisk.manager_interface.each do |event|
#   ahn_log.events event.inspect
# end
#
# This assumes you gave :events => true to the config.asterisk.enable_ami method in config/startup.rb
#
##
# Here is a list of the events included by default:
#
# - events.exception
# - events.asterisk.manager_interface
# - events.after_initialized
# - events.shutdown
# - events.asterisk.before_call
# - events.asterisk.failed_call
# - events.asterisk.hungup_call
#
#
# Note: events are mostly for components to register and expose to you.
##

events.exception.each do |e|
  ahn_log.error "#{e.class}: #{e.message}"
  ahn_log.error e.backtrace.join("\n\t")
end

events.asterisk.manager_interface.each do |event|
  begin
  ahn_log event.name.downcase

  manager = Adhearsion::VoIP::Asterisk.manager_interface
  channel = event.headers["Channel"]
  case event.name.downcase
  when 'conferencejoin'
    ahn_log.debug event.name
    Conference.add_participant channel
    Conference.play_sound 'conf-enter'
  when 'conferenceleave'
    Conference.remove_participant channel
    Conference.play_sound 'conf-exit'
  when 'hangup'
    ahn_log.conf.info "#{channel} hung up"
  when 'conferencestate'
    ahn_log.conf.debug event.headers.inspect
    ahn_log.conf.info "#{channel} is speaking" if event.headers["State"] == 'Speaking'
  when 'dtmf'
    Conference.play_for_dtmf event.headers["Digit"] if event.headers["End"] == "Yes"
    ahn_log.conf.debug event.headers.inspect
  end
  rescue => e
    puts e.message
    puts e.backtrace.join("\n")
  end
end


class Conference
  include Singleton

  attr_reader :participants

  DTMF_AUDIO = {0 => 'gambling-drunk',
                1 => 'office-iguanas',
                2 => 'tt-weasels',
                3 => 'telephone-in-your-pocket',
                4 => 'computer-friend1'}

  def initialize
    @participants = []
  end

  def add_participant(channel_id)
    synchronize { @participants << channel_id }
  end

  def remove_participant(channel_id)
    synchronize { @participants.delete channel_id }
  end

  def play_sound(name)
    participants.each do |channel|
      ahn_log.event_handler.debug "Playing #{name} to #{channel}"
      Adhearsion::VoIP::Asterisk.manager_interface.send_action "Command", "Command" => "konference play sound #{channel} rubyconf/#{name}"
    end
  end

  def play_for_dtmf(digit)
    play_sound DTMF_AUDIO[digit.to_i]
  end

  def self.method_missing(method_name, *args, &block)
    instance.send method_name, *args, &block
  end
end


