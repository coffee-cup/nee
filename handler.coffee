
# Base handler class to be extended
exports.Handler =
class Handler
  service_name: 'Base'

  # Default handler fun
  # Should never get called
  handler_func: (message) ->
    console.log 'Default handler func for', @service_name
