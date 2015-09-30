Slack = require 'slack-client'
jsonfile = require 'jsonfile'
Handlers = require './handlers'
handlers = Handlers.handlers

{Message} = require './message'

# List of available services
handler_services = h.service_name for h in handlers

creds = jsonfile.readFileSync('./creds.json')

# Config settings for slack bot
cf =
  token: creds.SLACK_TOKEN
  autoReconnect: true
  autoMark: true
  name: 'nee'

# The bot!
slack = new Slack(cf.token, cf.autoReconnect, cf.autoMark)

# Will call all appropriate handlers for message array
handleMessage = (message) ->
  available_services = (sn.service_name for sn in handlers)
  matching_handlers = (h for h in handlers when h.service_name is message.service_name)
  h.handler_func message for h in matching_handlers

# First thing to read message
# Checks if it is a link
# if it pass, pass message to handlers
readMessage = (slack_message) ->
  if slack_message.type is 'message' and slack_message.message
    m = slack_message.message

    # if it is a link
    if m.attachments
      messages = (new Message a for a in m.attachments)
      handleMessage m for m in messages

# Slack events
# Handle app
slack.on 'open', ->
  console.log 'Slackbot', cf.name, 'started'

slack.on 'message', (message) ->
  readMessage(message)

slack.on 'error', (err) ->
  console.log "Error", err

# Start it up
slack.login()
