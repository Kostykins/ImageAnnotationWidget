
define [
  "underscore",
  "common/has_parent",
  "common/collection",
  "common/plot_widget",
], (_, HasParent, Collection, PlotWidget) ->

  class BoxSelectionView extends PlotWidget
    b_color = null     #color of box outline, starts null
    box_array = []     #array containing box object information
    initialize: (options) ->
      @selecting = false
      @xrange = [null, null]
      @yrange = [null, null]
      super(options)
      @plot_view.$el.find('.bokeh_canvas_wrapper').append(@$el)

    boxselect: (xrange, yrange) ->
      @xrange = xrange
      @yrange = yrange
      @request_render()

    saveselect: (xrange, yrange) ->
      box_object = {
        id: box_array.length
        xrange: xrange
        yrange: yrange
        borderColor: b_color
        label: ""
      }
      if box_array.length == 0 or (box_array[box_array.length-1].xrange != box_object.xrange and box_array[box_array.length-1].xrange != box_object.yrange)
        box_array.push(box_object)

    startselect: () ->
      @selecting = true
      @xrange = [null, null]
      @yrange = [null, null]
      @request_render()

    stopselect: () ->
      @selecting = false
      @xrange = [null, null]
      @yrange = [null, null]
      b_color = null
      @request_render()
      @renderlabels()


    bind_bokeh_events: (options) ->
      @toolview = @plot_view.tools[@mget('tool').id]
      @listenTo(@toolview, 'boxselect', @boxselect)
      @listenTo(@toolview, 'startselect', @startselect)
      @listenTo(@toolview, 'stopselect', @stopselect)
      @listenTo(@toolview, 'saveselect', @saveselect)
      @listenTo(@toolview, 'renderlabels', @renderlabels)
      @listenTo(@toolview, 'grabboxarray', @grabboxarray)

    renderlabels: () ->
      #check if a new box_object had been created by checking last last labelContainer
      labelClass = "labelContainer#{box_array[box_array.length-1].id}"
      checkForPrevLabel = document.getElementsByClassName(labelClass)
      #if box_object has not been rendered(length < 1), create divs and append
      if checkForPrevLabel.length < 1
        #get box_object values
        height = Math.abs(box_array[box_array.length-1].yrange[1] - box_array[box_array.length-1].yrange[0])
        width = Math.abs(box_array[box_array.length-1].xrange[1] - box_array[box_array.length-1].xrange[0])
        left = Math.abs(box_array[box_array.length-1].xrange[0])
        top = @plot_view.canvas.vy_to_sy(Math.max(box_array[box_array.length-1].yrange[0], box_array[box_array.length-1].yrange[1]))
        #Create the container for all label information
        labelContainer = document.createElement('div')
        labelContainer.className = "labelContainer#{box_array[box_array.length-1].id}"
        labelContainer.style.width = @plot_view.canvas.width
        labelContainer.style.height = @plot_view.canvas.height
        #Create the div to show label text
        labelTextDiv = document.createElement('div')
        labelTextDiv.className = "labelText #{box_array[box_array.length-1].id}"
        labelTextDiv.style.top = "#{top}px"
        labelTextDiv.style.left = "#{left + width + 10}px"
        labelTextDiv.style.width = "#{240}px"
        labelTextDiv.style.height = "#{height - 14}px"
        labelTextDiv.innerText = "Click to add a label"
        #Create the box_object
        labelBox = document.createElement('div')
        labelBox.className = "labelBox #{box_array[box_array.length-1].id}"
        labelBox.style.top = "#{top}px"
        labelBox.style.left = "#{left}px"
        labelBox.style.width = "#{width}px"
        labelBox.style.height = "#{height}px"
        labelBox.style.border = "3px dashed #{box_array[box_array.length-1].borderColor}"
        #append divs
        labelContainer.appendChild(labelBox)
        labelContainer.appendChild(labelTextDiv)
        document.getElementsByClassName('bokeh plotview bokeh_canvas_wrapper')[0].appendChild(labelContainer)

    grabboxarray: (x,y) ->
      if box_array.length > 0
        for box in box_array
          if x >= box.xrange[0] and x <= box.xrange[1] and y >= box.yrange[0] and y <= box.yrange[1]
            @createDialog(box)


    createDialog: (box) ->
      overlay_container = document.createElement('div')
      overlay_container.className = "dialog-overlay"
      overlay_container.style.width = @plot_view.canvas.width
      overlay_container.style.height = @plot_view.canvas.height
      d_box = document.createElement('div')
      d_box.className = "dialog-box"
      d_box.innerText = "Would you like to Remove this selection, or add a label?"
      label_button = document.createElement('button')
      box_remove_button = document.createElement('button')
      label_button.id = "label-button"
      box_remove_button.id = "box-remove-button"
      label_button.innerText = "Add Label"
      box_remove_button.innerText = "Remove Box"
      d_box.appendChild(label_button)
      d_box.appendChild(box_remove_button)
      overlay_container.appendChild(d_box)
      document.getElementsByClassName('bk-plot-canvas-wrapper')[0].appendChild(overlay_container)
      button_selection = ""
      document.getElementById('label-button').onclick = ->
        button_selection = "label"
        document.getElementsByClassName('bk-plot-canvas-wrapper')[0].removeChild(overlay_container)
        label_text = prompt("Enter a new label for this box", "")
        if label_text != null and label_text.length > 0
          box.label = label_text
          labelTextBox = document.getElementsByClassName("labelText #{box.id}")[0]
          labelTextBox.innerText = label_text.toString()
        return
      document.getElementById('box-remove-button').onclick = ->
        button_selection = "remove"
        document.getElementsByClassName('bk-plot-canvas-wrapper')[0].removeChild(overlay_container)
        index = box_array.indexOf(box);
        $('.labelContainer'+box.id).remove()
        if(index > -1)
          box_array.splice(index, 1)
          console.debug(box_array)
        return

    getRandomColor: () ->
      letters = "0123456789ABCDEF".split("")
      color = "#"
      i = 0
      while i < 6
        color += letters[Math.floor(Math.random() * 16)]
        i++
      return color

    render: () ->
      style_string = ""
      if not @selecting
        @$el.removeClass('shading')
        @$el.removeAttr('style', style_string)
        return
      xrange = @xrange
      yrange = @yrange
      if _.any(_.map(xrange, _.isNullOrUndefined)) or
        _.any(_.map(yrange, _.isNullOrUndefined))
          @$el.removeClass('shading')
          @$el.removeAttr('style', style_string)
          return
      if xrange
        xpos = @plot_view.canvas.vx_to_sx(Math.min(xrange[0], xrange[1]))
        width = Math.abs(xrange[1] - xrange[0])
      else
        xpos = 0
        width = @plot_view.frame.get('width')
      style_string += "; left:#{xpos}px; width:#{width}px; "
      if yrange
        ypos = @plot_view.canvas.vy_to_sy(Math.max(yrange[0], yrange[1]))
        height = Math.abs(yrange[1] - yrange[0])
      else
        ypos = 0
        height = @plot_view.frame.get('height')
      if b_color == null
        b_color = @getRandomColor()
      @$el.addClass("shading")
      style_string += "top:#{ypos}px; height:#{height}px; border: 3px dashed #{b_color};"
      @$el.attr('style', style_string)


  class BoxSelection extends HasParent
    default_view: BoxSelectionView
    type: "BoxSelection"

    defaults: ->
      return _.extend {}, super(), {
        tool: null
        level: 'overlay'
      }

  class BoxSelections extends Collection
    model: BoxSelection

  return {
    "Model": BoxSelection,
    "Collection": new BoxSelections(),
    "View": BoxSelectionView
  }

