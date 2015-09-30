{Handler} = require '../handler'

exports.YoutubeHandler =
class YoutubeHandler extends Handler
  service_name: 'YouTube'
  handler_func: (@message) ->
    console.log 'calling', @service_name, 'handler. link:', @message.link
