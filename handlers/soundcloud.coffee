{Handler} = require '../handler'

exports.SoundcloudHandler =
class SoundcloudHandler extends Handler
  service_name: 'SoundCloud'
  handler_func: (@message) ->
    console.log 'calling', @service_name, 'handler. link:', @message.link
