class visualization.SensorGroup

  constructor: (@layer, @data, @options = {}) ->
    @items = []
    console.log "Layer: ", @layer
    for zone in @data
      lnglat = zone.shape.coordinates
      @items.push
        name: zone.name
        point: [lnglat[1], lnglat[0]]
        radius: zone.radius ? @options.radius
        group: zone.group
        fillColor: zone.shapeColor
        popup: zone.popup
        sensorId: zone.sensorId
    if this.valid()
      @items = @items.sort (a, b) ->
        a.name > b.name
      @groups = {}
      for {group, name, fillColor} in @items
        @groups[group] or= fillColor
      console.log "Icon group computed"
    else
      console.warn "Invalid categories"

  # Build layer as wanted
  buildLayerGroup: (widget, globalStyle = {}) ->
    group = []
    # Shadow
    for zone in @items
      console.log zone
      zoneStyle =
        icon: new L.Icon.SensorDefault()
        fillColor: zone.fillColor ? @options.fillColor
        radius: zone.radius ? @options.radius
        stroke: false
        fillOpacity: 1
      console.log zoneStyle
      zoneLayer = new L.marker(zone.point, zoneStyle)
      zoneLayer.sensorId = zone.sensorId
      widget._bindPopup(zoneLayer, zone)
      group.push(zoneLayer)
    group

  # Build HTML legend for given points computed layer
  buildLegend: () ->
    html  = "<div class='leaflet-legend-item' id='legend-#{@layer.name}'>"
    html += "<h3>#{@layer.label}</h3>"
    html += "<div class='leaflet-legend-body leaflet-categories-scale'>"
    html += "<span class='leaflet-categories-items'>"
    for group in Object.keys(@groups)
      html += "<span class='leaflet-categories-item'>"
      html += "<i class='leaflet-categories-sample' style='background-color: #{@groups[group]};'></i>"
      html += " <span class='leaflet-categories-item_label'>#{group}</span>"
      html += "</span>"
    html += "</span>"
    html += "</div>"
    html += "</div>"
    return html

  # Returns the item matching the given name
  itemFor: (name) ->
    back = null
    @items.forEach (item, index, array) ->
      back = item if item.name == name
    return back

  # Check if categories are valid
  valid: () ->
    @items.length > 0

visualization.registerLayerType "sensor_group", visualization.SensorGroup
