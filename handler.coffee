
# Base handler class to be extended
exports.Handler =
class Handler
  service_name: 'Base'
  cmd: 'h'

  # Default handler fun
  # Should never get called
  handler_func: (message, channel) ->
    return console.log 'Default handler func for', @service_name

  # Default start auth func
  start_auth: (channel) ->
    return 'Default handler start_auth func for ' +  @service_name

  # Returns if handler is auth or not
  # Default is always false
  is_auth: () ->
    return false

  # Handles a command sent to @cmd
  handle_command: (cmds, channel) ->
    console.log 'default handler handling command function'
