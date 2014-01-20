# Dialog windows
#
class window.Alchemy.Dialog

  DEFAULTS:
    header_height: 36
    size: '400x300'
    padding: true
    title: ''
    modal: true
    image_loader: true
    image_loader_color: '#fff'
    ready: ->

  # Arguments:
  #  - url: The url to load the content from via ajax
  #  - options: A object holding options
  #    - size: The maximum size of the Dialog
  #    - title: The title of the Dialog
  constructor: (@url, @options = {}) ->
    @options = $.extend({}, @DEFAULTS, @options)
    @$document = $(document)
    @$body = $('body')
    size = @options.size.split('x')
    @width = parseInt(size[0], 10)
    @height = parseInt(size[1], 10)
    @build()

  # Opens the Dialog and loads the content via ajax.
  open: ->
    @dialog.trigger 'Alchemy.DialogOpen'
    @bind_close_events()
    window.requestAnimationFrame =>
      @dialog_container.addClass('open')
    @load()
    true

  # Closes the Dialog and removes it from the DOM
  close: ->
    @$document.off 'keydown'
    @dialog_container.removeClass('open')
    @$document.on 'webkitTransitionEnd transitionend oTransitionEnd', =>
      @$document.off 'webkitTransitionEnd transitionend oTransitionEnd'
      @dialog_container.remove()
      @dialog.trigger 'Alchemy.DialogClose'
    true

  # Loads the content via ajax and replaces the Dialog body with server response.
  load: ->
    @show_spinner()
    $.get @url, (data) =>
      @replace(data)
    .fail (xhr) =>
      @show_error(xhr)
    true

  # Reloads the Dialog content
  reload: ->
    @dialog_body.empty()
    @load()

  # Replaces the dialog body with given content and initializes it.
  replace: (data) ->
    @remove_spinner()
    @dialog_body.hide()
    @dialog_body.html(data)
    @init()
    @options.ready.call()
    @dialog_body.show('fade', 200)
    true

  # Adds a spinner into Dialog body
  show_spinner: ->
    @spinner = Alchemy.Spinner.medium()
    @spinner.spin(@dialog_body[0])

  # Removes the spinner from Dialog body
  remove_spinner: ->
    @spinner.stop()

  # Initializes the Dialog body
  init: ->
    Alchemy.GUI.init(@dialog_body)
    $('#overlay_tabs', @dialog_body).tabs()
    @watch_remote_forms()

  # Watches ajax requests inside of dialog body and replaces the content accordingly
  watch_remote_forms: ->
    form = $('[data-remote="true"]', @dialog_body)
    form.bind "ajax:complete", (e, xhr, status) =>
      content_type = xhr.getResponseHeader('Content-Type')
      if status == 'success'
        if content_type.match(/javascript/)
          @close()
        else
          @dialog_body.html(xhr.responseText)
          @init()
      else
        @show_error(xhr, status)

  # Displays an error message
  show_error: (xhr, status_message) ->
    error_type = "warning"
    switch xhr.status
      when 0
        error_header = "The server does not respond."
        error_body = "Please check server and try again."
      when 403
        error_header = "You are not authorized!"
        error_body = "Please close this window."
      else
        error_type = "error"
        if status_message
          error_header = status_message
          console.error eval(xhr.responseText)
        else
          error_header = "#{xhr.statusText} (#{xhr.status})"
        error_body = "Please check log and try again."
    $errorDiv = $("<div class=\"message #{error_type}\" />")
    $errorDiv.append '<span class="icon icon-warning"></span>'
    $errorDiv.append "<h1>#{error_header}</h1>"
    $errorDiv.append "<p>#{error_body}</p>"
    @dialog_body.html $errorDiv

  # Binds close events on:
  # - Close button
  # - Overlay (if the Dialog is a modal)
  # - ESC Key
  bind_close_events: ->
    @close_button.click =>
      @close()
      false
    if @overlay
      @overlay.addClass('closable').click =>
        @close()
        false
    @$document.keydown (e) =>
      if e.which == 27
        @close()
        false
      else
        true

  # Builds the html structure of the Dialog
  build: ->
    @dialog_container = $('<div class="alchemy-dialog-container" />')
    @dialog = $('<div class="alchemy-dialog" />')
    @dialog_body = $('<div class="alchemy-dialog-body" />')
    @dialog_header = $('<div class="alchemy-dialog-header" />')
    @dialog_title = $('<div class="alchemy-dialog-title" />')
    @close_button = $('<a class="alchemy-dialog-close"><span class="icon close small"></span></a>')
    @dialog_title.text(@options.title)
    @dialog_header.append(@dialog_title)
    @dialog_header.append(@close_button)
    @dialog.append(@dialog_header)
    @dialog.append(@dialog_body)
    @dialog.css
      'max-width': @width
      'min-height': @height
    @dialog_body.css
      'min-height': @height - @DEFAULTS.header_height
    if @options.modal
      @overlay = $('<div class="alchemy-dialog-overlay" />')
      @dialog_container.append(@overlay)
    @dialog_container.append(@dialog)
    @dialog.addClass('modal') if @options.modal
    @dialog_body.addClass('padded') if @options.padding
    @$body.append(@dialog_container)
    @dialog

# Utility function to close the current Dialog
#
# You can pass a callback function, that gets triggered after the Dialog gets closed.
#
window.Alchemy.closeCurrentDialog = (callback) ->
  if Alchemy.currentDialog
    Alchemy.currentDialog.dialog.on('Alchemy.DialogClose', callback)
    Alchemy.currentDialog.close()

# Utility function to open a new Dialog
window.Alchemy.openDialog = (url, options) ->
  if !url
    throw('No url given! Please provide an url.')
  Alchemy.currentDialog = new Alchemy.Dialog(url, options)
  Alchemy.currentDialog.open()

# Watches elements for Alchemy Dialogs
#
# Links having a data-alchemy-dialog or data-alchemy-confirm-delete
# and input/buttons having a data-alchemy-confirm attribute get watched.
#
# You can pass a scope so that only elements inside this scope are queried.
#
# The href attribute of the link is the url for the overlay window.
#
# See Alchemy.Dialog for further options you can add to the data attribute
#
window.Alchemy.watchForDialogs = (scope) ->
  $('a[data-alchemy-dialog]', scope).click (e) ->
    $this = $(this)
    url = $this.attr('href')
    options = $this.data('alchemy-dialog')
    Alchemy.openDialog(url, options)
    false
  $('a[data-alchemy-confirm-delete]', scope).click (event) ->
    $this = $(this)
    options = $this.data('alchemy-confirm-delete')
    Alchemy.confirmToDeleteDialog($this.attr('href'), options)
    false
  $('input[data-alchemy-confirm], button[data-alchemy-confirm]', scope).click (event) ->
    options = $(this).data('alchemy-confirm')
    Alchemy.openConfirmDialog options.message, $.extend options,
      ok_label: options.ok_label
      cancel_label: options.cancel_label
      on_ok: =>
        Alchemy.pleaseWaitOverlay()
        @form.submit()
        return
    false