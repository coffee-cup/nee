{Handler} = require './handler'
{YoutubeHandler} = require './handlers/youtube'
{SoundcloudHandler} = require './handlers/soundcloud'

# create handlers
y = new YoutubeHandler
s = new SoundcloudHandler


# List of handlers for messages
exports.handlers = [y]
