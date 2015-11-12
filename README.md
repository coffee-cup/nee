# nee

A small Slack bot whose purpose is to grab links from a channel and throw them into an online playlist (*e.g. All Youtube links in #general will be added to a youtube playlist*).

At the moment Youtube is the only handler available. A handler is a class that which contains the service name from the Slack API it wishes to grab links from. If a link posted to a connected channel has a service name that matches one of the handlers, the message is sent to the handler for handling.

Handlers need to be authenticated before use, which can be done with `@nee a`

### Commands

**cmd** | **desc**
--- | --- | ---
@nee a | Authenticate all handlers
@nee y a [index|playlist] | Authenticate with Youtube
@nee y l | List authenicated users playlists
@nee y c | List all connections
@nee y m [index|playlist] | Make a connection to index or playlist name
@nee y r [index|playlist] | Remove a connection to index or playlist name
