
define [
  "jquery_mousewheel"
], (mousewheel) ->

  set_bokehXY = (event) ->
    offset = $(event.currentTarget).offset()
    left = if offset? then offset.left else 0
    top = if offset? then offset.top else 0
    event.bokehX = event.pageX - left
    event.bokehY = event.pageY - top

  class TwoPointEventGenerator

    constructor: (options) ->
      @restrict_to_innercanvas = options.restrict_to_innercanvas
      @options = options
      @toolName = @options.eventBasename
      @dragging = false
      @basepoint_set = false
      @button_activated = false
      @tool_active = false

    bind_bokeh_events: (plotview, eventSink) ->
      toolName = @toolName
      @plotview = plotview
      @eventSink = eventSink
      callbacks = @plotview.canvas.get('mousemove_callbacks')
      callbacks.push((e, x, y) =>
        if not @tool_active
          return
        if not @dragging
          return

        set_bokehXY(e)
        if not @basepoint_set
          @dragging = true
          @basepoint_set = true
          eventSink.trigger("#{toolName}:SetBasepoint", e)
        else
          eventSink.trigger("#{toolName}:UpdatingMouseMove", e)
          e.preventDefault()
          e.stopPropagation()
      )
      callbacks.push((e, x, y) =>
        if @dragging
          set_bokehXY(e)
          h_range = @plotview.frame.get(
            'h_range')
          v_range = @plotview.frame.get(
            'v_range')
          x = @plotview.canvas.sx_to_vx(e.bokehX)
          y = @plotview.canvas.sy_to_vy(e.bokehY)
          if @restrict_to_innercanvas
            xstart = h_range.get('start')
            xend = h_range.get('end')
            ystart = v_range.get('start')
            yend = v_range.get('end')
          else
            xstart = 0
            xend = @plotview.canvas.get('width')
            ystart = 0
            yend = @plotview.canvas.get('height')
          if x < xstart  or x > xend
            @_stop_drag(e)
            return false
          if y < ystart or y > yend
            @_stop_drag(e)
            return false
      )
      @plotview.canvas.set('mousemove_callbacks', callbacks)
      $(document).bind('keydown', (e) =>
        if e.keyCode == 27 # ESC
          eventSink.trigger("clear_active_tool"))

      $(document).bind('keyup', (e) =>
        if not e[@options.keyName]
          @_stop_drag(e))

      @plotview.canvas_view.canvas_wrapper.bind('mousedown', (e) =>
        if @_try_start(e)
          @_start_drag()
          return false)
      @plotview.canvas_view.canvas_wrapper.bind('mouseup', (e) =>
        if @tool_active
          if not @basepoint_set
            @_click(e)
          else
            @_stop_drag(e)
          return false)
      @plotview.canvas_view.canvas_wrapper.bind('mouseleave', (e) =>
        if @tool_active
          @_stop_drag(e)
          return false)

      @$tool_button = $("<button class='bk-toolbar-button #{@options.buttonHook}' title='#{@options.buttonText}'><img class='bk-btn-icon' src='#{@options.buttonIcon}'/><span class='tip'>#{@options.buttonText}</span></button>")
      @plotview
      @plotview.$el.find('.bk-button-bar').append(@$tool_button)

      # Paddy: I want to remove all this checking for @button_activated,
      # is there some way we can do this in a more declarative way,
      # maybe a state machine?
      #
      # What is the difference between tool_active and button_activated?
      # I once knew, but now I forget

      @$tool_button.click(=>
        if @button_activated
          eventSink.trigger("clear_active_tool")
        else
          eventSink.trigger("active_tool", toolName))

      eventSink.on("#{toolName}:deactivated", =>
        @tool_active=false;
        @button_activated = false;
        @$tool_button.removeClass('active'))

      eventSink.on("#{toolName}:activated", =>
        @tool_active=true;
        @$tool_button.addClass('active')
        @button_activated = true)
      return eventSink

    hide_button: ->
      @$tool_button.hide()

    _try_start: (e)->
      if @button_activated or @eventSink.active == @toolName
        @tool_active = true
        return true
      else if not @eventSink.active
        if @options.keyName is null and not e.ctrlKey and not e.altKey and not e.metaKey and not e.shiftKey
          @tool_active = true
          return true
        else if e[@options.keyName] is true
          @tool_active = true
          return true
      return false

    _start_drag: ->
      @_activated_with_button = @button_activated
      @eventSink.trigger("active_tool", @toolName)
      if not @dragging
        @dragging = true
        if not @button_activated
          @$tool_button.addClass('active')
        if @options.cursor?
          @plotview.canvas_view.canvas_wrapper.css('cursor', @options.cursor)

    _stop_drag: (e)->
      @basepoint_set = false
      if @dragging
        @dragging = false
        if @_activated_with_button is false and @options.auto_deactivate is true
          @eventSink.trigger("clear_active_tool")
        if not @button_activated
          @$tool_button.removeClass('active')
        if @options.cursor?
          @plotview.canvas_view.canvas_wrapper.css('cursor', '')
        set_bokehXY(e)
        @eventSink.trigger("#{@options.eventBasename}:DragEnd", e)
      @_activated_with_button = null

    _click: (e)->
      @dragging = false
      if @_activated_with_button is false and @options.auto_deactivate is true
        @eventSink.trigger("clear_active_tool")
      set_bokehXY(e)
      @eventSink.trigger("#{@options.eventBasename}:MouseClicked", e)
      e.preventDefault()
      e.stopPropagation()

  class OnePointWheelEventGenerator

    constructor: (options) ->
      @options = options
      @toolName = @options.eventBasename
      @dragging = false
      @basepoint_set = false
      @button_activated = false
      @tool_active = false

    bind_bokeh_events: (plotview, eventSink) ->
      toolName = @toolName
      @plotview = plotview
      @eventSink = eventSink
      @plotview.canvas_view.canvas_wrapper.mousewheel(
        (e, delta) =>
          if @tool_active or (not @eventSink.active and e.shiftKey)
            set_bokehXY(e)
            e.delta = delta
            eventSink.trigger("#{toolName}:zoom", e)
            e.preventDefault()
            e.stopPropagation()
      )

      $(document).bind('keydown', (e) =>
        #disable the tool when ESC is pressed
        if e.keyCode == 27
          eventSink.trigger("clear_active_tool"))

      @plotview.$el.bind("mousein", (e) =>
        eventSink.trigger("clear_active_tool"))

      @plotview.$el.bind("mouseover", (e) =>
        @mouseover_count += 1)

      @$tool_button = $("<button class='bk-toolbar-button #{@options.buttonHook}' title='#{@options.buttonText}'><img class='bk-btn-icon' src='#{@options.buttonIcon}'/><span class='tip'>#{@options.buttonText}</span></button>")
      @plotview.$el.find('.bk-button-bar').append(@$tool_button)

      @$tool_button.click(=>
        if @button_activated
          eventSink.trigger("clear_active_tool")
        else
          eventSink.trigger("active_tool", toolName)
          @button_activated = true)

      no_scroll = (el) ->
        el.setAttribute("old_overflow", el.style.overflow)
        el.style.overflow = "hidden"
        if el == document.body
          return
        else
          no_scroll(el.parentNode)
      restore_scroll = (el) ->
        el.style.overflow = el.getAttribute("old_overflow")
        if el == document.body
          return
        else
          restore_scroll(el.parentNode)

      eventSink.on("#{toolName}:deactivated", =>
        @tool_active=false;
        @button_activated = false;
        @$tool_button.removeClass('active')
        document.body.style.overflow = @old_overflow)

      eventSink.on("#{toolName}:activated", =>
        @tool_active=true;
        @$tool_button.addClass('active'))

      return eventSink
    hide_button: ->
      @$tool_button.hide()

  class ButtonEventGenerator

    constructor: (options) ->
      @options = options
      @toolName = @options.eventBasename
      @button_activated = false
      @tool_active = false

    bind_bokeh_events: (plotview, eventSink) ->
      toolName = @toolName
      @plotview = plotview
      @eventSink = eventSink

      $(document).bind('keydown', (e) =>
        #disable the tool when ESC is pressed
        if e.keyCode == 27
          eventSink.trigger("clear_active_tool"))

      @plotview.$el.bind("mouseover", (e) =>
        @mouseover_count += 1)
 
      @$tool_button = $("<button class='bk-toolbar-button #{@options.buttonHook}' title='#{@options.buttonText}'><img class='bk-btn-icon' src='#{@options.buttonIcon}'/><span class='tip'>#{@options.buttonText}</span></button>")
      @plotview.$el.find('.bk-button-bar').append(@$tool_button)

      @$tool_button.click(=>
        if @button_activated
          eventSink.trigger("clear_active_tool")
        else
          eventSink.trigger("active_tool", toolName)
          @button_activated = true)

      no_scroll = (el) ->
        el.setAttribute("old_overflow", el.style.overflow)
        el.style.overflow = "hidden"
        if el == document.body
          return
        else
          no_scroll(el.parentNode)
      restore_scroll = (el) ->
        el.style.overflow = el.getAttribute("old_overflow")
        if el == document.body
          return
        else
          restore_scroll(el.parentNode)

      eventSink.on("#{toolName}:deactivated", =>
        @tool_active=false;
        @button_activated = false;
        @$tool_button.removeClass('active')
        document.body.style.overflow = @old_overflow)

      eventSink.on("#{toolName}:activated", =>
        @tool_active=true;
        @$tool_button.addClass('active'))

      return eventSink
    hide_button: ->
      @$tool_button.hide()

  return {
    "TwoPointEventGenerator": TwoPointEventGenerator,
    "OnePointWheelEventGenerator": OnePointWheelEventGenerator,
    "ButtonEventGenerator": ButtonEventGenerator,
  }
