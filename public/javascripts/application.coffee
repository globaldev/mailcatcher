# Add a new jQuery selector expression which does a case-insensitive :contains
jQuery.expr[':'].icontains = (a, i, m) ->
  (a.textContent ? a.innerText ? "").toUpperCase().indexOf(m[3].toUpperCase()) >= 0

class MailCatcher
  constructor: ->
    $('#messages tr').live 'click', (e) =>
      e.preventDefault()
      @loadMessage $(e.currentTarget).attr 'data-message-id'

    $('input[name=search]').keyup (e) =>
      query = $.trim $(e.currentTarget).val()
      if query
        @searchMessages query
      else
        @clearSearch()

    $('#message .views .format.tab a').live 'click', (e) =>
      e.preventDefault()
      @loadMessageBody @selectedMessage(), $($(e.currentTarget).parent('li')).data 'message-format'

    $('#message .views .analysis.tab a').live 'click', (e) =>
      e.preventDefault()
      @loadMessageAnalysis @selectedMessage()

    $('#resizer').live
      mousedown: (e) ->
        e.preventDefault()
        $(window).bind events =
          mouseup: (e) ->
            e.preventDefault()
            $(window).unbind events
          mousemove: (e) ->
            e.preventDefault()
            $('#messages').css
              height: e.clientY - $('#messages').offset().top

    $('nav.app .clear a').live 'click', (e) =>
      e.preventDefault()
      if confirm "You will lose all your received messages.\n\nAre you sure you want to clear all messages?"
        $.ajax
          url: '/messages'
          type: 'DELETE'
          success: ->
            $('#messages tbody, #message .metadata dd').empty()
            $('#message .metadata .attachments').hide()
            $('#message iframe').attr 'src', 'about:blank'
          error: ->
            alert 'Error while quitting.'

    $('nav.app .quit a').live 'click', (e) =>
      e.preventDefault()
      if confirm "You will lose all your received messages.\n\nAre you sure you want to quit?"
        $.ajax
          type: 'DELETE'
          success: ->
            location.replace $('body > header h1 a').attr('href')
          error: ->
            alert 'Error while quitting.'

    $('#message .views .deliver a').live 'click', (e) ->
      recipient = prompt "Please enter recipient email address"
      if recipient
        e.preventDefault()
        id = _this.selectedMessage() || 1
        $deliver = $(this).parent()
        deliver_html = $deliver.html()
        $deliver.text 'Delivering...'
        $.ajax
          url: "/messages/#{id}/#{recipient}/deliver",
          type: 'POST',
          success: ->
            $deliver.html deliver_html
            alert 'Message successfully delivered'
          error: ->
            $deliver.html deliver_html
            alert 'An error occurred while attempting to deliver this message'

    key 'up', =>
      id = @selectedMessage() || 1
      id -=  1  if id > 1
      @loadMessage(id)

    key 'down', =>
      id = @selectedMessage() || @messagesCount()
      id += 1 if id < @messagesCount()
      @loadMessage(id)

    key '⌘+up, ctrl+up', =>
      @loadMessage(1)

    key '⌘+down, ctrl+down', =>
      @loadMessage @messagesCount()

    key 'left', =>
      @openTab @previousTab()

    key 'right', =>
      @openTab @nextTab()

    @refresh()
    @subscribe()

  # Only here because Safari's Date parsing *sucks*
  # We throw away the timezone, but you could use it for something...
  parseDateRegexp: /^(\d{4})[-\/\\](\d{2})[-\/\\](\d{2})(?:\s+|T)(\d{2})[:-](\d{2})[:-](\d{2})(?:([ +-]\d{2}:\d{2}|\s*\S+|Z?))?$/
  parseDate: (date) ->
    if match = @parseDateRegexp.exec(date)
      new Date match[1], match[2] - 1, match[3], match[4], match[5], match[6], 0

  offsetTimeZone: (date) ->
    offset = Date.now().getTimezoneOffset() * 60000 #convert timezone difference to milliseconds
    date.setTime(date.getTime() - offset)
    date

  formatDate: (date) ->
    date &&= @parseDate(date) if typeof(date) == "string"
    date &&= @offsetTimeZone(date)
    date &&= date.toString("dddd, d MMM yyyy h:mm:ss tt")

  messagesCount: ->
    $('#messages tr').length - 1

  tabs: ->
    $('#message ul').children('.tab')

  getTab: (i) =>
    $(@tabs()[i])

  selectedTab: =>
    @tabs().index($('#message li.tab.selected'))

  openTab: (i) =>
    @getTab(i).children('a').click()

  previousTab: (tab)=>
    i = if tab || tab is 0 then tab else @selectedTab() - 1
    i = @tabs().length - 1 if i < 0
    if @getTab(i).is(":visible")
      i
    else
      @previousTab(i-1)

  nextTab: (tab) =>
    i = if tab then tab else @selectedTab() + 1
    i = 0 if i > @tabs().length - 1
    if @getTab(i).is(":visible")
      i
    else
      @nextTab(i+1)

  haveMessage: (message) ->
    message = message.id if message.id?
    $("#messages tbody tr[data-message-id=\"#{message}\"]").length > 0

  selectedMessage: ->
    $('#messages tr.selected').data 'message-id'

  searchMessages: (query) ->
    selector = (":icontains('#{token}')" for token in query.split /\s+/).join ""
    $rows = $("#messages tbody tr")
    $rows.not(selector).hide()
    $rows.filter(selector).show()

  clearSearch: ->
    $('#messages tbody tr').show()

  addMessage: (message) ->
    $('#messages tbody').append \
      $('<tr />').attr('data-message-id', message.id.toString())
        .append($('<td/>').text(message.sender or "No sender").toggleClass("blank", !message.sender))
        .append($('<td/>').text((message.recipients || []).join(', ') or "No receipients").toggleClass("blank", !message.recipients.length))
        .append($('<td/>').text(message.subject or "No subject").toggleClass("blank", !message.subject))
        .append($('<td/>').text @formatDate message.created_at)

  loadMessage: (id) ->
    id = id.id if id?.id?
    id ||= $('#messages tr.selected').attr 'data-message-id'

    if id?
      $('#messages tbody tr:not([data-message-id="'+id+'"])').removeClass 'selected'
      $('#messages tbody tr[data-message-id="'+id+'"]').addClass 'selected'

      $.getJSON '/messages/' + id + '.json', (message) =>
        $('#message .metadata dd.created_at').text @formatDate message.created_at
        $('#message .metadata dd.from').text message.sender
        $('#message .metadata dd.to').text (message.recipients || []).join(', ')
        $('#message .metadata dd.subject').text message.subject
        $('#message .views .tab.format').each (i, el) ->
          $el = $(el)
          format = $el.attr 'data-message-format'
          if $.inArray(format, message.formats) >= 0
            $el.find('a').attr('href', '/messages/' + id + '.' + format)
            $el.show()
          else
            $el.hide()

        if $("#message .views .tab.selected:not(:visible)").length
          $("#message .views .tab.selected").removeClass "selected"
          $("#message .views .tab:visible:first").addClass "selected"

        if message.attachments.length
          $ul = $('<ul/>').appendTo($('#message .metadata dd.attachments').empty())

          $.each message.attachments, (i, attachment) ->
            $ul.append($('<li>').append($('<a>').attr('href', attachment['href']).addClass(attachment['type'].split('/', 1)[0]).addClass(attachment['type'].replace('/', '-')).text(attachment['filename'])));
          $('#message .metadata .attachments').show()
        else
          $('#message .metadata .attachments').hide()

        $('#message .views .download a').attr 'href', "/messages/#{id}.eml"

        if $('#message .views .tab.analysis.selected').length
          @loadMessageAnalysis()
        else
          @loadMessageBody()

  # XXX: These should probably cache their iframes for the current message now we're using a remote service:

  loadMessageBody: (id, format) ->
    id ||= @selectedMessage()
    format ||= $('#message .views .tab.format.selected').attr 'data-message-format'
    format ||= 'html'

    $("#message .views .tab[data-message-format=\"#{format}\"]:not(.selected)").addClass 'selected'
    $("#message .views .tab:not([data-message-format=\"#{format}\"]).selected").removeClass 'selected'

    if id?
      $('#message iframe').attr "src", "/messages/#{id}.#{format}"

  loadMessageAnalysis: (id) ->
    id ||= @selectedMessage()

    $("#message .views .analysis.tab:not(.selected)").addClass 'selected'
    $("#message .views :not(.analysis).tab.selected").removeClass 'selected'

    if id?
      # Makes a new iframe and populate it with a quick intro and a button
      $iframe = $('#message iframe').contents().children()
        .html("""
          <html>
          <head>
          <title>Analysis</title>
          #{$('link[rel="stylesheet"]')[0].outerHTML}
          </head>
          <body class="iframe">
          <h1>Analyse your email with Fractal</h1>
          <p><a href="http://getfractal.com/" target="_blank">Fractal</a> is a really neat service that applies common email design and development knowledge from <a href="http://www.email-standards.org/" target="_blank">Email Standards Project</a> to your HTML email and tells you what you've done wrong or what you should do instead.</p>
          <p>Please note that this <strong>sends your email to the Fractal service</strong> for analysis. Read their <a href="http://getfractal.com/terms" target="_blank">terms of service</a> if you're paranoid.</p>
          <form>
          <input type="submit" value="Analyse" /><span class="loading" style="color: #999; display: none">Analysing&hellip;</span>
          </form>
          </body>
          </html>
        """)
      $form = $iframe.find('form')
        .submit (e) ->
          e.preventDefault()
          $(this)
            .find('input[type="submit"]').attr('disabled', 'disabled').end()
            .find('.loading').show()
          $('#message iframe').contents().find('body').xslt("/messages/#{id}/analysis.xml", "/stylesheets/analysis.xsl")

  refresh: ->
    $.getJSON '/messages', (messages) =>
      $.each messages, (i, message) =>
        unless @haveMessage message
          @addMessage message

  subscribe: ->
    if WebSocket?
      @subscribeWebSocket()
    else
      @subscribePoll()

  subscribeWebSocket: ->
    secure = window.location.scheme == 'https'
    @websocket = new WebSocket("#{if secure then 'wss' else 'ws'}://#{window.location.host}/messages")
    @websocket.onmessage = (event) =>
      @addMessage $.parseJSON event.data

  subscribePoll: ->
    unless @refreshInterval?
      @refreshInterval = setInterval (=> @refresh()), 1000


$ -> window.MailCatcher = new MailCatcher