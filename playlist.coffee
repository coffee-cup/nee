
# Class to hold playlist data
exports.Playlist =
class Playlist

  constructor: (item) ->
    @kind = item.kind
    @id = item.id
    @publishedAt = item.snippet.publishedAt
    @channelId = item.snippet.channelId
    @title = item.snippet.title
    @channelTitle = item.snippet.channelTitle
