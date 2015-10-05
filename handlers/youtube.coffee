jsonfile = require 'jsonfile'
Lien = require 'lien'
Express = require 'express'
app = new Express
Youtube = require 'youtube-api'
refresh = require '../refresh_token'

{Playlist} = require '../playlist'
{Handler} = require '../handler'

storage = require 'node-persist'
storage.initSync()

YOUTUBE_KEY = 'youtube_tokens'
YOUTUBE_CONNECTIONS = 'youtube_connections'

creds = jsonfile.readFileSync('./creds.json')

scope = ['https://www.googleapis.com/auth/youtube']
oauth_options =
  type: 'oauth'
  client_id: creds.YOUTUBE_CLIENT_ID
  client_secret: creds.YOUTUBE_CLIENT_SECRET
  redirect_url: creds.YOUTUBE_REDIRECT_URIS[0]

# Start server to send oauth redirects to
PORT = 5000
server = app.listen PORT, ->
  console.log 'started oauth callback server on port ' + PORT

# A connection object between channel name and youtube playlist
# Links sent to this handler will have to come from channel_id and then
# they will be sent to playlist_id
class Connection
  constructor: (@channel_name, @channel_id, @playlist_name, @playlist_id) ->

# Youtube Handler
# A handler is associate with 1 youtube account
# On the first message recieved, it will start the
# authentication process
exports.YoutubeHandler =
class YoutubeHandler extends Handler
  service_name: 'YouTube'
  cmd: 'y'
  playlists: []
  connections: []
  @creds: null

  constructor: () ->
    @get_credentials()
    if @creds and @creds.refresh_token and @creds.access_token
      oauth_options.refresh_token = @creds.refresh_token
      oauth_options.access_token = @creds.access_token

    @oauth = Youtube.authenticate oauth_options

    # Get user playlists if already have token
    if @is_auth
      @get_playlists()

    cons = storage.getItemSync(YOUTUBE_CONNECTIONS)
    if cons
      @connections = cons

  # Gets credentials from persit if they exist
  get_credentials: () ->
    creds = storage.getItemSync(YOUTUBE_KEY)
    if creds and creds.access_token and creds.refresh_token
      console.log 'Found creds in persist'
      # console.log creds
      @creds = creds


  # Saves current set of connections to storage
  save_connections: () =>
    storage.setItem(YOUTUBE_CONNECTIONS, @connections)

  # Removes current tokens from persist
  remove_tokens: () =>
    console.log 'removing tokens from persist for ' + @service_name
    storage.removeItemSync(YOUTUBE_KEY)
    @oauth.credentials.refresh_token = null
    @oauth.credentials.access_token = null
    @creds = null

  # Trys to refresh the access token with refresh token
  # Returns true if success full
  refresh_token: (callback) =>
    console.log 'refreshing token'
    if @creds and @creds.refresh_token
      refresh @creds.refresh_token, oauth_options.client_id, oauth_options.client_secret, (err, json, res) =>
        if err
          console.log err
          return
        if json.accessToken
          console.log 'got new access_token: ' + json.accessToken
          @creds.access_token = json.accessToken
          @oauth.setCredentials @creds
          storage.setItem(YOUTUBE_KEY, @creds)
          callback()

  # Gets youtube playlists and set obj var
  get_playlists: (try_refresh=true) =>
    params =
      part: 'snippet'
      mine: true
      maxResults: 50
    Youtube.playlists.list params, (err, data) =>
      if err
        if err.code is 401
          if try_refresh
            @refresh_token get_playlists, false
          else
            @remove_tokens()
        return
      if data.items
        @playlists = (new Playlist item for item in data.items)

  # Lists playlists and index to channel
  list_playlists: (channel, try_refresh=true) =>
    if not @is_auth()
      msg = 'Not authenticated with ' + @service_name + '. Run @nee ' + @cmd + ' a'
      channel.send msg
      return

    params =
      part: 'snippet'
      mine: true
      maxResults: 50
    Youtube.playlists.list params, (err, data) =>
      if err
        if err.code is 401
          if try_refresh
            @refresh_token =>
              @list_playlists channel, false
          else
            @remove_tokens()
            msg = 'Not authenticated with ' + @service_name + '. Run @nee ' + @cmd + ' a'
            channel.send msg
        return

      if data.items
        @playlists = (new Playlist item for item in data.items)

        if @playlists.length > 0
          s = 'Your Playlists \n'
          addToS = (i, p) =>
            s += (i+1) + ' : ' + p + '\n'
          addToS i, p.title for p, i in @playlists
          channel.send s
        else
          channel.send 'No playlists'

  # List all connections for this handler to channel
  list_connections: (channel) =>
    if not @is_auth()
      channel.send 'Not authenticated with ' + @service_name + '. Run @nee ' + @cmd + ' a'
      return

    if @connections.length > 0
      s = 'Your Connections\n'
      addToS = (i, c) =>
        s += (i+1) + ' : ' + '#' + c.channel_name + ' -> ' + c.playlist_name + '\n'
      addToS i, c for c, i in @connections
      channel.send s
    else
      channel.send 'No connections. Create one with @nee y m [index|playlist]'

  # Removes a connection from the handler
  remove_connection: (cmds, channel) =>
    if not @is_auth()
      channel.send 'Not authenticated with ' + @service_name + '. Run @nee a'
      return
    if cmds.length > 0
      i = parseInt cmds[0]
      if i
        i -= 1
        if i >= 0 and i < @connections.length
          c = @connections[i]
          channel.send 'Removing connection: ' + '#' + c.channel_name + ' -> ' + c.playlist_name + '\n'
          @connections.splice i, 1
          @save_connections()
        else
          channel.send 'Connection index was out of bounds'
      else
        name = cmds[0]
        find = (c for c in @connections when c.channel_id is channel.id and c.playlist_name is name)
        if find.length > 0
          i = @connections.indexOf find[0]
          if i isnt -1
            c = connections[i]
            channel.send 'Removing connection: ' + '#' + c.channel_name + ' -> ' + c.playlist_name + '\n'
            @connections.splice i, 1
            @save_connections()
    else
      channel.send 'Enter connection index or playlist name to remove connection'

  # Makes a new connection for the channel and playlist if not already there
  make_new_connection: (channel, playlist) ->
    find = (c for c in @connections when c.channel_id is channel.id and c.playlist_id is Playlist.id)
    if find and find.length is 0
      return new Connection channel.name, channel.id, playlist.title, playlist.id
    return null

  # Make connection from this channel to youtube playlist
  # specified by index or name
  make_connection: (cmds, channel) =>
    if not @is_auth()
      channel.send 'Not authenticated with ' + @service_name + '. Run @nee a'
      return

    if cmds.length > 0
      i = parseInt cmds[0]
      # The command is playlist index
      if i
        i -= 1
        if i >= 0 and i < @playlists.length
          pl = @playlists[i]
          con = @make_new_connection channel, pl
          if con
            @connections.push con
            @save_connections()
            channel.send 'Made connection: ' + '#' + con.channel_name + ' -> ' + con.playlist_name + '\n'
          else
            channel.send 'This connection already exists'
        else
          channel.send 'Playlist index was out of bounds'
      else # The command is a playlist name
        name = cmds[0]
        find = (p for p in @playlists when p.title is name)
        if find.length > 0
          pl = find[0]
          con = @make_new_connection channel, pl
          if con
            @connections.push con
            @save_connections()
            channel.send 'Made connection: ' + '#' + con.channel_name + ' -> ' + con.playlist_name + '\n'
          else
            channel.send 'This connection already exists'
        else
          channel.send 'Could not find playlist with name ' + name
    else
      channel.send 'Enter index or playlist name to make connection'

  # Write this handlers help to the channel
  show_help: (channel) =>
    message = 'Help for ' + @service_name + ' handler'
    message = '
      Help for YouTube handler \n
      [l] List authenticated users playlists \n
      [c] List all connections \n
      [m index|playlist] make a connection to index or playlist name \n
      [r index|playlist] remove a connection to index or playlist name \n
      [a] authenticate with youtube \n
      [h] show help \n
    '
    channel.send message

  # Handle the user command directed at this handler
  handle_command: (cmds, channel) =>
    if cmds.length > 0
      if cmds[0] is 'l'
        @list_playlists channel
      else if cmds[0] is 'm'
        rest = cmds.splice 1, cmds.length
        @make_connection rest, channel
      else if cmds[0] is 'c'
        @list_connections channel
      else if cmds[0] is 'r'
        rest = cmds.splice 1, cmds.length
        @remove_connection rest, channel
      else if cmds[0] is 'a'
        @start_auth channel
      else if cmds[0] is 'h'
        @show_help channel
    else
      @show_help channel

  # Returns if handler is authenticated
  is_auth: () ->
    if @oauth.credentials.access_token
      return true
    return false

  # Start the authentication process for the handler
  start_auth: (channel) ->
    if @is_auth()
      channel.send 'Already authed for ' + @service_name
      return

    console.log 'starting oauth process'

    t_auth = @oauth
    t_name = @service_name
    get_p = @get_playlists

    # create callback to get token code from
    app.get '/oauth2callback', (req, res) ->
      code = req.query.code

      # try to get token with oauth code from youtube
      t_auth.getToken code, (err, tokens) =>
        if err
          res.status 500
          console.log err
          return res.send 'Error getting tokens'

        # success!!
        t_auth.setCredentials tokens
        @creds = tokens
        storage.setItem(YOUTUBE_KEY, tokens)
        console.log 'got tokens for ' + t_name
        console.log tokens
        channel.send 'You have authenticated with ' + t_name + '!'
        get_p()
        return res.send 'got tokens!'

    url = @oauth.generateAuthUrl {access_type: 'offline', scope: scope}
    response = 'Please authenticate ' + @service_name + '\n' + url
    channel.send response

  # Adds link from message to playlist in connection
  add_link_to_connection: (channel, message, connection, try_refresh=true) ->
    video_id = (message.link.split 'v=')[1]
    amperPos = video_id.indexOf '&'
    if amperPos isnt -1
      video_id = video_id.substring 0, amperPos

    params =
      part: 'snippet'
      resource:
        snippet:
          playlistId: connection.playlist_id
          resourceId:
            kind: 'youtube#video'
            videoId: video_id

    Youtube.playlistItems.insert params, (err, data) =>
      if err
        if err.code is 401
          if try_refresh
            @refresh_token =>
              @add_link_to_connection channel, message, connection, false
          else
            @remove_tokens()
            msg = 'Not authenticated with ' + @service_name + '. Run @nee ' + @cmd + ' a'
            channel.send msg
        return
      console.log 'Added ' + video_id + ' to ' + connection.playlist_name

  # A youtube link was added to the channel
  handler_func: (message, channel) ->
    # console.log 'calling', @service_name, 'handler. link:', message.link

    find = (c for c in @connections when c.channel_id is channel.id)
    @add_link_to_connection channel, message, c for c in find

