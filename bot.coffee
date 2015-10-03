Slack = require 'slack-client'
jsonfile = require 'jsonfile'
Handlers = require './handlers'
handlers = Handlers.handlers

{Message} = require './message'

creds = jsonfile.readFileSync('./creds.json')

# Config settings for slack bot
cf =
  token: creds.SLACK_TOKEN
  autoReconnect: true
  autoMark: true
  name: 'nee'
  user_id: ''

# The bot!
slack = new Slack(cf.token, cf.autoReconnect, cf.autoMark)

# Authorize all handlers
authorizeHandlers = (channel) ->
  h.start_auth channel for h in handlers

# Calls handler with message if it is authed
callHandler = (h, message, channel) ->
  if h.is_auth()
    response = h.handler_func message, channel
    # sendMessage channel, response
  else
    response = h.service_name + ' handler not authorized. run @' + cf.name + ' a'
    sendMessage channel, response

# Will call all appropriate handlers for message array
handleMessage = (message, channel) ->
  matching_handlers = (h for h in handlers when h.service_name is message.service_name)
  callHandler h, message, channel for h in matching_handlers

# Process user command
handleCommand = (cmds, channel) ->
  if cmds.length > 0
    if cmds[0] is 'a'
      authorizeHandlers channel
    else
      # loop through handlers cmds and call their handle command func
      # with the rest of the commands, cmds[1, cmd.length]
      rest_commands = cmds.slice 1, cmds.length
      h.handle_command rest_commands, channel for h in handlers when h.cmd is cmds[0]

# First thing to read message
# Checks if it is a link
# if it is, pass message to handlers
readMessage = (slack_message, user, c) ->
  if slack_message.type is 'message' and slack_message.message
    m = slack_message.message
    # if it is a link
    if m.attachments
      messages = (new Message a for a in m.attachments)
      handleMessage m, c for m in messages
  else
    t = slack_message.text
    in_chat_name = '<@' + cf.user_id + '>'
    if t.startsWith in_chat_name
      cmd = t.replace in_chat_name + ' ', ''
      cmds = cmd.split ' '
      handleCommand cmds, c

# Send message to slack channel or #general if non specified
sendMessage = (channel, message) ->
  if channel and message and message isnt ''
    channel.send message
    console.log 'sending message', message

# Slack events
# Handle app
slack.on 'open', ->
  cf.name = slack.self.name
  cf.user_id = slack.self.id

  channels = []
  groups = []
  unreads = slack.getUnreadCount()

  # Get all the channels that bot is a member of
  channels = (channel.name for id, channel of slack.channels when channel.is_member)

  console.log 'Welcome to Slack, You are @' + slack.self.name + ' of ' + slack.team.name
  console.log 'You are in: ' + channels.join(', ')
  console.log 'As well as: ' + groups.join(', ')

  messages = if unreads is 1 then 'message' else 'messages'

  console.log 'You have ' + unreads + ' unread ' + messages

slack.on 'message', (message) ->
  channel = slack.getChannelGroupOrDMByID(message.channel)
  user = slack.getUserByID(message.user)
  response = ''

  {type, ts, text} = message
  channelName = if channel?.is_channel then '#' else ''
  channelName = channelName + if channel then channel.name else 'UNKNOWN_CHANNEL'

  userName = if user?.name? then "@#{user.name}" else "UNKNOWN_USER"

  readMessage(message, user, channel)

slack.on 'error', (err) ->
  console.log "Error", err

# Start it up
slack.login()
