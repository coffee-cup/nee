exports.Message =
class Message

  # Creates message from slack message obj
  constructor: (sm) ->
    @service_name = sm.service_name
    @service_url = sm.service_url
    @link = sm.title_link
    @author = sm.author_name
    @title = sm.title

  # Prints message nicely
  printMessage: () ->
    console.log @title, '-', @link
